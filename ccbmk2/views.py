"""Views for CCBuilder Mk.II"""

import datetime
import os
import sys

from flask import jsonify, render_template, request
import pymongo

from ccbmk2 import app
from ccbmk2.model_building import build_coiled_coil


client = pymongo.MongoClient('db', 27017)
parameters_store = client.ccbuilder.requested_parameters
build_log = client.ccbuilder.build_log
model_store = client.ccbuilder.models


@app.route('/')
def welcome():
    """Welcome to CCBuilder splash screen."""
    return render_template('welcome.html')


@app.route('/builder')
def builder():
    """Main view for the builder interface."""
    return render_template('builder.html')


@app.route('/builder/api', methods=['POST'])
def process_builder_command():
    """Processes commands passed to the builder module."""
    (parameters_id, save_model) = store_parameters(request.json)
    model = model_store.find_one(request.json)
    if model is None:
        build_start_time = datetime.datetime.now()
        pdb_and_score = build_coiled_coil(request.json)
        build_start_end = datetime.datetime.now()
        build_time = build_start_end - build_start_time
        log_build_request(request, build_time, parameters_id)
        if save_model:
            store_model(request.json, pdb_and_score)
    else:
        pdb_and_score = {'pdb': model['pdb'], 'score': model['score']}
    return jsonify(pdb_and_score)


def store_parameters(request, number_for_save=5):
    parameters_log = parameters_store.find_one(request)
    if parameters_log == None:
        parameters_log = request
        parameters_log['requested'] = 1
        parameters_id = parameters_store.insert_one(parameters_log).inserted_id
    else:
        parameters_log['requested'] += 1
        parameters_id = parameters_log['_id']
        parameters_store.update_one(
            {'_id': parameters_id},
            {'$set': {'requested': parameters_log['requested']}})
    if parameters_log['requested'] == number_for_save:
        save_model = True
    else:
        save_model = False
    return parameters_id, save_model


def log_build_request(request, build_time, parameters_id):
    build_request = {
        'ip': request.remote_addr,
        'date': datetime.datetime.now(),
        'build_time': build_time.total_seconds(),
        'parameters_id': parameters_id
    }
    build_log.insert_one(build_request)
    return


def store_model(request, pdb_and_score):
    model = request
    model['pdb'] = pdb_and_score['pdb']
    model['score'] = pdb_and_score['score']
    model_store.insert_one(model)
    return
