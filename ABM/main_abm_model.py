## ABM MAIN SCRIPT - scenario where activities are driven by NHTS trip chains, and places are chosen based on LODES/Advan data
## Adapted to incorporate a synthetic population with health characteristics 

# Import required packages for the model
from typing import Dict, Tuple
from mpi4py import MPI
import numpy as np
from dataclasses import dataclass

from repast4py import core, random, space, schedule, logging, parameters
from repast4py import context as ctx
import repast4py
from repast4py.space import DiscretePoint as dpt
from repast4py.space import ContinuousPoint as cpt

import logging as pylog
from datetime import datetime, timedelta
import pandas as pd
import sys
import os
import random as rndm
import ast
import json

# local imports
current_dir = os.path.dirname(__file__)
sys.path.append(os.path.dirname(__file__))
from human_agent.human_agent import Human, Human_Config
from human_agent import disease

# model = None
agent_tuple_cache = {}
log = pylog.getLogger(__name__)

# Function for Repast4Py - handles saving, moving and reconstructing agents in parallel 
def restore_agent(agent_tuple: Tuple):
    uid = agent_tuple[0] # gets the agent's unique ID

    if uid in agent_tuple_cache: # if the agent already exists in memory
        # Agent exists in cache.
        agent = agent_tuple_cache[uid] # re-use it
    else: # if the agent does not exist, then create it
        # Cache this agent
        agent = Human(uid[0], uid[1], uid[2]) #(agent_id, rank)
        agent_cfg = agent_tuple[1]
        agent.set_cfg(agent_cfg)
        agent_tuple_cache[uid] = agent

    agent_cfg = agent_tuple[1]
    agent.set_cfg(agent_cfg)

    return agent

class Model:
    """
    The Model class encapsulates the simulation, and is
    responsible for initialization (scheduling events, creating agents,
    and the grid the agents inhabit), and the overall iterating
    behaviour of the model.

    Args:
        comm: the mpi communicator over which the model is distributed.
        params: the simulation input parameters
    """
    def __init__(self, comm: MPI.Intracomm, params: Dict):
        '''
        Initialise the Model Class
        '''
        # prints a start up message
        log.info('Initialising Repast model...')
        
        # create the schedule
        self.runner = schedule.init_schedule_runner(comm) # creates the schedule runner
        self.runner.schedule_repeating_event(1, 1, self.step) # tells the model to run a step, each tick (start at tick 1, repeat every 1 tick)
        self.runner.schedule_stop(params['stop.at']) # when to stop the simulation (parameter is entered in .yaml file)
        self.runner.schedule_end_event(self.end_sim) # when the simulation ends, runs a clean up/log function

        self.rank = comm.Get_rank() # gets MPI rank (processor)
        self.load_buildings_dict() # for implementing the function to load spatial data - buildings
        self.load_dwell_time()  # for implementing the function to load dwell time data
        self.load_restaurants() #  for implementing the function to load spatial data - restaurants
        self.load_recreations() #  for implementing the function to load spatial data - recreation places
        self.load_errands() # for implementing the function to load spatial data - errand places
        self.load_hospitals() #  for implementing the function to load spatial data - hospitals
        
         
        coords = [1578015, 43715, 1893069, 44225] # defining grid bounding box - spatial bounds
        self.building_ids = list(self.dbuildings.keys()) # stores all building ids for quick lookup

        # model parameters
        self.infection_chance = params['infection_chance'] # stores a key parameter used for disease spread (parameter set in .yaml file)
        self.infection_chance_with_vaccine = params['infection_chance_with_vaccine']

        # create the context to hold the agents and manage cross process
        # synchronization
        self.context = ctx.SharedContext(comm)

        # creates/defines the simulation area/box
        box = space.BoundingBox(coords[0], coords[1],
                                coords[2], coords[3], 0, 0)
        # create a SharedGrid of 'box' size with sticky borders that allows multiple agents
        # in each grid location. Agents cant leave the area, buffer added (??)
        self.grid = space.SharedGrid(name='grid', bounds=box, borders=space.BorderType.Sticky,
                                     occupancy=space.OccupancyType.Multiple, buffer_size=10, comm=comm)
        self.context.add_projection(self.grid) # attach grid to context, links agent to space

        # setting up agent logging, specifically a csv
        log_file = params['agent_log_file']+'.csv'
        # writes a csv file with the following info...
        self.agent_logger = logging.TabularLogger(comm, log_file,
                                                  ['tick', 'agent_id','disease_state',
                                                   'x', 'y','n_infected', 'agents_contacted'])

        # Initialise human agents
        n_agents = params['pop_size'] # determines number of agents (from parameter in .yaml file)
        world_size = comm.Get_size() # Returns the total size of the MPI communicator
        humans_per_rank = int(n_agents / world_size) # calculates number of agents per rank
        remaining_humans = n_agents % world_size # calculates number of agents not evenly distributed
        if self.rank < remaining_humans: # assigns agents to rank
            humans_per_rank += 1
        first_id = self.rank * humans_per_rank      # id of the first agent on this process
        if remaining_humans > 0: # assigns remaining agents 
            if self.rank >= remaining_humans:
                first_id += remaining_humans
    
        rng = np.random.default_rng(seed=42) # get random seed
        # randomly selects X number of agents to be infected at the start, based on parameter in .yaml file
        init_infected = rng.choice(n_agents, int(n_agents * params['infectious_start_rate']))
        init_infected = np.isin(np.arange(n_agents), init_infected) #  marks True for agent IDs present in the init_infected list/array and False otherwise
        infectious_count = init_infected.sum() # counts how many are infected to start

        # read the agent input file (input file in .yaml file)
        with open(params['input_agents']) as file:
            next(file)          # skip header
            for input_agent in range(0, first_id+humans_per_rank): # only read rows for this processor's agents
                if input_agent < first_id:          # skip input rows till agent id for this process 
                    next(file) # skips line / row 
                else: # read agent data and extract values from each line (extracts from csv , parsing manually)
                    input_line = file.readline()
                    human_id = int(input_line.split('[')[0].split(',')[0])
                    nhts_id = (int(input_line.split('[')[0].split(',')[1]))
                    agent_type = (int(input_line.split('[')[0].split(',')[2]))
                    census_tract = (int(input_line.split('[')[0].split(',')[3]))
                    #trip_chain = ast.literal_eval("["+input_line.split('[')[1].split('"')[0])

                    trip_chain = ast.literal_eval("[" + input_line.split('[')[1].split(']')[0] + "]")

                    # NEW: get the value after the closing bracket
                    vaccinated = int(input_line.split(']')[1].split(',')[1].strip())

                    # Force infection only in one census tract (only agents in this tract can start infected)
                    if census_tract != 51059440800: # if the agent is NOT in this tract
                        init_infected[human_id] = False # sets initial infected status to FALSE
                        infectious_count = infectious_count-1 # infectious count is subtracted by 1
                    self.add_human_agent_v2(human_id, nhts_id, trip_chain, census_tract,
                                            agent_type, init_infected[human_id], vaccinated) # adds human agent to the simulation 
        
        # time setting, each simulation tick represents 60 minutes
        self.tick_duration = 60               # minutes

        # setting up simulation start time (real world date)
        sim_start_str = '01/01/24 00:00:00'
        self.sim_start = datetime.strptime(sim_start_str, '%m/%d/%y %H:%M:%S')
        # will track current time, and advances each tick - first set as start time
        self.current_time = self.sim_start  

    # creates buildings from file
    def load_buildings_dict(self):

        # --- Creating dictionary with buildings
        self.dbuildings = {}

        # --- Reading the input file of buildings from .yaml file
        file_path=params['input_buildings'] # gets the file path 
        dframe = pd.read_csv(file_path) # reads csv file from the path entered
        self.dbuildings = {dframe.iloc[i]['bldg_id']: # creates a dictionary from looping through the df, each key is a building ID, and the value is a dictionary contraining building info (type, central coords)
                        {"type": dframe.iloc[i]['bldg_type'], 
                            "pos" : np.array([dframe.iloc[i]['x_centroid'], dframe.iloc[i]['y_centroid']],
                            dtype = int)} 
                    for i in dframe.T}

    # creates dwell time (how long people stay at a location) from file (json, from .yaml file)
    def load_dwell_time(self):
        with open(params['input_dwell_time'], "r") as json_file: #open the json file
            dwell_time = json.load(json_file) # loads into python dictionary (keys are strings)

        self.dwell_time = {int(k): v for k, v in dwell_time.items()} # creates a new dictionary where each key (k) is converted from string to int, and values (v) stay the same

    # read restaurants from file (similar to reading dwell time function)
    def load_restaurants(self):
        with open(params['input_restaurants'], "r") as json_file:
            restaurants = json.load(json_file) 

        # creates a new dictionary, where string keys (k) are converted to ints, converts the first array and second array to numpy arrays 
        self.restaurants = {int(k): (np.array(v[0]), np.array(v[1])) for k, v in restaurants.items()} 

    # read recreations from file (similar to resturants)
    def load_recreations(self):
        with open(params['input_recreations'], "r") as json_file:
            recreations = json.load(json_file) 

        self.recreations = {int(k): (np.array(v[0]), np.array(v[1])) for k, v in recreations.items()}

    # read errands from file (similar to recreation file)
    def load_errands(self):
        with open(params['input_errands'], "r") as json_file:
            errands = json.load(json_file) 

        self.errands = {int(k): (np.array(v[0]), np.array(v[1])) for k, v in errands.items()}

    # read hospitals from file (similar to errand file)
    def load_hospitals(self):
        with open(params['input_hospitals'], "r") as json_file:
            hospitals = json.load(json_file) 

        self.hospitals = {int(k): (np.array(v[0]), np.array(v[1])) for k, v in hospitals.items()}

    # function to start the simulation loop, runs simulation schedule
    def start(self):
        self.runner.execute()
        
    # function that ends simulation and cleans up and logs
    def end_sim(self):
        '''
        Clean up and log data.
        '''
        log.info(f'Cleaning up simulation...')
        self.end_start_timestamp = datetime.now()
        self.agent_logger.close()

        return
    
    # Function to create human agent and place them in the simulation
    #human_id: unique ID for the agent
    #nhts_id: ID tied to travel survey schedule
    #trip_chain: list of places the agent will visit
    #census_tract: home area
    #agent_type: category of human ???????????????
    #init_infected: whether they start infected
    def add_human_agent_v2(self, human_id, nhts_id, trip_chain, census_tract, agent_type, init_infected, vaccinated):
        '''
        Add agent to the sim located at Point(x,y) based on the home id
        '''
        #building_to_go = self.dframe[self.dframe['bldg_id'] == home_id]
        home_id = trip_chain[-1] # determines the home building by taking the last location in the trip chain (assumes the final stop in the daily trip chain is home)
        start_minutes = self.dwell_time[nhts_id][0] # gets the agent's start time, looks up how long the agent stays at their first location
        building_to_go = self.dbuildings[home_id] # gets the home building location, pulls the home building record
        pt = dpt(building_to_go["pos"][0], # converts building coordinates to a grid point 
                building_to_go["pos"][1])
        human = Human(human_id, agent_type, self.rank) # creates/instantiates a human object
        human_cfg = Human_Config() # build a configuration object - builder
        human_cfg_object = human_cfg.rand_factory(pt.x, pt.y, home_id, nhts_id, trip_chain, census_tract, vaccinated, 
                                                  start_minutes, init_infected, params) # generates a full configuration for the agent
        human.set_cfg(human_cfg_object) # attach configuration to agent
        self.context.add(human) # add agent to simulation context
        self.grid.move(human, pt) # place agent on spatial grid, at their home location

        #print(f"Agent {human_id} vaccinated = {vaccinated}")
    
    # Function to move agents through their daily travel schedule
    def nhts_schedule(self, human):
        # Check if it is time to move: if the agent has finished staying at the current place, then time to go to the next place
        if(human.trip_end_datetime <= self.current_time):
            next_trip = human.trip_chain[human.trip_num] # gets the next trip type
            if next_trip == 'restaurants': # if it is restaurants,  
                ct_blgs = self.restaurants[human.census_tract] # look up restaurants buildings in that census tract (ACCORDING TO AGENT'S HOME CENSUS TRACT)
                next_trip = np.random.choice(ct_blgs[0], p=ct_blgs[1]) # randomly choose location, based on weights
            elif next_trip == 'recreation': # same process repeats, similar to if statement above
                ct_blgs = self.recreations[human.census_tract]
                next_trip = np.random.choice(ct_blgs[0], p=ct_blgs[1])
            elif next_trip == 'errands':
                ct_blgs = self.errands[human.census_tract]
                next_trip = np.random.choice(ct_blgs[0], p=ct_blgs[1])
            elif next_trip == 'hospitals':
                ct_blgs = self.hospitals[human.census_tract]
                next_trip = np.random.choice(ct_blgs[0], p=ct_blgs[1])

            dwell_time = self.dwell_time[human.nhts_id][human.trip_num+1] # get how long the agent stays at that place
            human.trip_end_datetime = self.current_time + timedelta(minutes=dwell_time) # set when they will leave next
            self.go_to_place(human, next_trip) # move agent to the new building
            human.trip_num += 1 # set new trip number counter
            if human.trip_num == len(human.trip_chain): # if the agent is finished with their trip chain
                human.trip_num = 0 # resets trip counter

    # Function to move agent to a building
    def go_to_place(self, human, place_id):
        next_bldg = self.dbuildings[place_id] # gets building record 
        x = next_bldg["pos"][0] # get X coordinate
        y = next_bldg["pos"][1] # get Y coordinate
        human.move_coords(self, x, y) # tell agent to move itself on the grid

    # Function to infect other agents/disease spread at shared locations
    def disease_spread(self, human):
        # find and infect another susceptible agent at same place if human is infected
        pt = model.grid.get_location(human) # get the current location of the agent
        n_at_place = model.grid.get_num_agents(pt) # count how many agents are at that location
        n_potential_agents = round(np.log2(n_at_place)) # limit how many contacts occur using log function (more people = more contacts, but contacts increase slowly with log scale)

        agents_counter = 0 # set a counter 
        for other_agent in self.grid.get_agents(pt): # loop through other agents in same location, for each one
            if agents_counter >= n_potential_agents: # breaks the loop after enough contacts 
                break
            if other_agent.id != human.id: # avoid self-contact, so if the other agent id is NOT the same as the current agent's ID
                human.unique_contacts.append(other_agent.id) # track contacts by appending to a list
                agents_counter += 1 # update counter 
                if human.disease_state is disease.Disease_State.INFECTIOUS: # if this agent is infectious
                   
                   ## CHANGED THIS PART TO ACCOUNT FOR VACCINE BEHAVIOR
                   # A random number is generated between 0 and 1, if that number is less than the infection chance then the agent will become infected
                   # BUT if the other agent is vaccinated, then use the vaccine-designated infection chance
                   # Else, if they are not vaccinated, then use the original infection chance
                    if np.random.rand() < (
                        self.infection_chance_with_vaccine 
                        if other_agent.vaccinated==1
                        else self.infection_chance): 

                            # Print debug info to verify the newly added vaccine logic
                        # print(
                        #     f"Agent {other_agent.id} could be exposed! "
                        #     f"Vaccinated?: {other_agent.vaccinated}, "
                        #     f"Used infection chance: {self.infection_chance_with_vaccine if other_agent.vaccinated==1 else self.infection_chance}"
                        # )

                        if human.count_infected == True: ### NOT SURE AB THIS PART!!!
                            human.infected_counter += 1 # add to counter that track how many other agents they have infected
                       
                        # let an infectious agent infect susceptible with a given probability
                        if other_agent.disease_state == disease.Disease_State.SUSCEPTIBLE: # if the other agent is susceptible
                            disease.become_exposed(other_agent, params) # then, the other agent becomes exposed
                            #print(f"Agent {other_agent.id} WAS exposed! ")
        
        # check disease state timers if agent is not susceptible
        if human.disease_state is not disease.Disease_State.SUSCEPTIBLE:
            disease.check_disease_state(human, params)
        if human.disease_state is disease.Disease_State.RECOVERED: # stop counting infections once recovered
            human.count_infected = False

    # Function which acts as the main simulation tick
    def step(self):
        '''
        Increment the sim by one step.
        
        '''
        comm = MPI.COMM_WORLD
        rank = comm.Get_rank()
        if rank == 0:
            log.info(f"  - tick: {self.runner.schedule.tick}") #outputs the simulation tick
        
        self.current_time  = self.current_time + timedelta(minutes=self.tick_duration) # advances simulation clock

        for human in self.context.agents(): # for each agent
            human.timestamp = self.current_time # updates time     
            self.nhts_schedule(human) # call scheduling function

        self.context.synchronize(restore_agent) # synchronize across processors
        for human in self.context.agents(): # for each agent
            self.disease_spread(human) # call disease spread function
        self.log_human_agents() # log results

        return
    
    # function for logging agents
    def log_human_agents(self): 
        for human in self.context.agents(): # for each agent
            # log the tick, ID, disease state, coordiantes, number infected, and contacts it had
            self.agent_logger.log_row(self.runner.schedule.tick, human.id, human.disease_state,
                                      human.current_x, human.current_y, human.infected_counter, human.unique_contacts)            
            human.unique_contacts = [] # clears contact list for next tick
        self.agent_logger.write() # writes to a file

    # function for starting the simulation 
    def start(self):
        self.runner.execute()

# setting up logging
def setup_logging(params):
    '''
    Setup the logging for both Repast4Py as well as a normal python logger
    '''
    loglevel = 'INFO'
    pylog.basicConfig(level=loglevel, format='%(asctime)s %(relativeCreated)6d %(threadName)s ::%(levelname)-8s %(message)s')
    log = pylog.getLogger()
    return log

 # function for running the simulation (calls the start function to execute simulation schedule)
def run(params: Dict):
    global model
    model = Model(MPI.COMM_WORLD, params)
    model.start()

# main script for simulation if run directly
if __name__ == "__main__":
    parser = parameters.create_args_parser()
    args = parser.parse_args()
    params = parameters.init_params(args.parameters_file, args.parameters)
    setup_logging(params)
    run(params)
    log.info('==END==')
