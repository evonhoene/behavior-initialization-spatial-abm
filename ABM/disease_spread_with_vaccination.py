## DISEASE DYNAMICS
# Defines possible disease states, how agents transition between states
    # How infection happens when agents interact, and how time controls disease progression

# Importing required packages
import random as rndm
from typing import Tuple 
from enum import Enum
import ast
import datetime
import logging as pylog # Repast logger is called as "logging" 

# Creating log file
log = pylog.getLogger(__name__)
 
## Disease State CLASS
class Disease_State(str, Enum):
    # defines possible disease stages (string inheritance, so values are strings)
  SUSCEPTIBLE = "Susceptible"
  EXPOSED = "Exposed"
  INFECTIOUS = "Infectious"
  RECOVERED = "Recovered"

# Funtion called when someone gets infected but still in incubation (EXPOSED STAGE)
def become_exposed(agent, params):
    '''
    What happens when the agent becomes exposed.
    '''
    random_params = ast.literal_eval(params['exposed_duration']) # reads duration of exposed stage from .yaml
    exposed_days = rndm.uniform(random_params[0], random_params[1]) # chooses random length from the exposed stage
    agent.disease_end_datetime = agent.timestamp + datetime.timedelta(days=exposed_days) # sets when exposed period ends
    agent.disease_state = Disease_State.EXPOSED # changes state to exposed
    return agent

# Funtion called when someone moves from exposed to infectious stage
def become_infected(agent, params):
    '''
    What happens when the agent becomes infected.
    '''
    random_params = ast.literal_eval(params['infection_duration']) # reads duration of infectious stage from .yaml
    infection_days = rndm.uniform(random_params[0], random_params[1]) # draws random duration from the stage's length
    agent.disease_end_datetime = agent.timestamp + datetime.timedelta(days=infection_days) # sets when infectious period ends
    agent.disease_state = Disease_State.INFECTIOUS # sets state to infectious
    return agent

# Funtion called when someone moves from infectious to recovered stage
def become_recovered(agent, params):
    '''
    What happens when the agent becomes recovered.
    '''
    random_params = ast.literal_eval(params['immunity_duration']) # reads duration of recovered stage from .yaml
    immunity_days = rndm.uniform(random_params[0], random_params[1]) # draws random duration from stage's length
    agent.disease_end_datetime = agent.timestamp + datetime.timedelta(days=immunity_days) # sets when recovered state is over
    agent.disease_state = Disease_State.RECOVERED # Sets agent's state to recovered
    return agent

# Function called when someone moves from recovered to susceptible stage
def become_susceptible(agent, params):
    '''
    What happens when the agent becomes susceptible.
    ''' 
    agent.disease_end_datetime = agent.timestamp # resets time stamp (since no longer in disease progression)
    agent.disease_state = Disease_State.SUSCEPTIBLE # sets agent's state to susceptible
    return agent

# TRANSMISSION: Function where disease is transmitted
# Logic:
# For each nearby person, if they are infectious, then a random number is selected, and infection will occur if the roll is less than the probability
# def check_infection_chance(agent, nearby_agents_list, params):
#     '''
#     Check if this agent has been infected by other agents.
#     '''
#     infection_chance = params['infection_chance'] # collect probability of infection from .yaml
#     infection_chance_with_vaccine = params['infection_chance_with_vaccine']
    
#     for other_agent in nearby_agents_list: # for (iterate through) each agent nearby
#         if other_agent.disease_state == Disease_State.INFECTIOUS: # if any of those agents nearby are infectious
#             if rndm.random() < infection_chance: # a random number is rolled, and if that is less than the infection chance...
#                 return True # then the agent will become infectious [TRUE is set for the variable]
#                 # ** note:this function does not change state -- it just determines if infection occurs!
#     return False # if none of the nearby agents are infectious, then FALSE is returned (agent does not have a chance of becoming infectious)

# DISEASE PROGRESSION: Function to check whether enough time has passed for the next stage
def check_disease_state(agent, params):
    '''
    Check the timers, check how the agents disease state progresses 
    '''
     # Checks if the agent's set end time for a disease stage is less than the current time stamp
     # this is so disease checks are done ONLY if enough time has passed since last state change: 
    if agent.disease_end_datetime < agent.timestamp:
       # if the agent is exposed 
        if agent.disease_state == Disease_State.EXPOSED:
            # change agent to be infected (determines length, end time, and sets state)
            agent = become_infected(agent, params)
            return agent
        
        # if the agent is infectious
        if agent.disease_state == Disease_State.INFECTIOUS:
            # change agent to be recovered (determines length, end time, and sets state)
            agent = become_recovered(agent, params)
            return agent

        # if the agent is recovered
        if agent.disease_state == Disease_State.RECOVERED:
            # change agent to be susceptible again (resets time ticker and sets state)
            agent = become_susceptible(agent, params)
            return agent
    else:
        return agent        
