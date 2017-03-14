"""Module for building models using ISAMBARD."""

import itertools
import sys

import isambard


registerAdjust = {
    'a': 0,
    'b': 102.8,
    'c': 205.6,
    'd': 308.4,
    'e': 51.4,
    'f': 154.2,
    'g': 257
}


def build_coiled_coil(parameters):
    """Builds a model of a coiled coil using the input parameters.
    
    Parameters
    ----------
    parameter : [ dict[str, int/float/str] ]
        List of parameter dictionaries required for building a coiled coil i.e.
        oligomer state, radius, pitch, phiCA, sequence.
    
    Returns
    -------
    model_data : dict
        A dictionary containing information about the model that has
        been produced.
    """
    coiled_coil = isambard.specifications.CoiledCoil(len(parameters), auto_build=False)
    coiled_coil.major_radii = [p['Radius'] for p in parameters]
    coiled_coil.major_pitches = [p['Pitch'] for p in parameters]
    raw_phi = [p['Interface Angle'] for p in parameters]
    registers = [p['Register'] for p in parameters]
    coiled_coil.phi_c_alphas = [ia + registerAdjust[r] for ia, r in zip(raw_phi, registers)]
    sequences = [p['Sequence'] for p in parameters]
    coiled_coil.rotational_offsets = [
        d + p['Super-Helical Rotation'] for d, p in zip(
            coiled_coil.rotational_offsets, parameters)]
    coiled_coil.orientations = [-1 if p['Orientation'] else 1 for p in parameters]
    coiled_coil.z_shifts = [p['Z-Shift'] for p in parameters]
    coiled_coil.build()
    coiled_coil.pack_new_sequences(sequences)
    ave_rpt = calculate_average_rpt(coiled_coil)
    model_data = {
        'pdb': coiled_coil.pdb,
        'mean_rpt_value': ave_rpt,
        'score':coiled_coil.buff_internal_energy.total_energy
        }
    return model_data


def calculate_average_rpt(ampal):
    """Returns the mean residues per turn value for an AMPAL object."""
    rpt_lists = [isambard.analyse_protein.residues_per_turn(ch)[:-1] for ch in ampal]
    rpt_values = list(itertools.chain(*rpt_lists))
    average_rpt = sum(rpt_values)/len(rpt_values)
    return average_rpt
