# Automatically generated, do not edit.
<%def name="indent(text, level=0)" buffered="True">
% for l in text.splitlines():
${' '*4*level}${l}
% endfor
</%def>

from libc.math cimport pow, sqrt
cimport numpy
from pysph.base.carray cimport DoubleArray, IntArray, UIntArray
from pysph.base.particle_array cimport ParticleArray
from pysph.base.nnps cimport NNPS

${helpers}

# #############################################################################
cdef class ParticleArrayWrapper:
    cdef public int index
    cdef public ParticleArray array
    cdef public IntArray tag, pid
    cdef public DoubleArray ${array_names}
    
    def __init__(self, pa, index):
        self.index = index
        self.array = pa
        props = set(pa.properties.keys())
        props = props.union(['tag', 'pid'])
        for prop in props:
            setattr(self, prop, pa.get_carray(prop))
        
    cpdef long size(self):
        return self.array.get_number_of_particles()
        
        
#${locator}

# #############################################################################
cdef class SPHCalc:
    cdef public ParticleArrayWrapper ${pa_names}
    cdef public NNPS nnps
    cdef UIntArray nbrs
    
    def __init__(self, *particle_arrays):
        for i, pa in enumerate(particle_arrays):
            name = pa.name
            setattr(self, name, ParticleArrayWrapper(pa, i))

        self.nbrs = UIntArray()

    def set_nnps(self, NNPS nnps):
        self.nnps = nnps            
    
    cpdef compute(self):
        cdef long nbr_idx, NP_SRC, NP_DEST
        cdef int s_idx, d_idx
        cdef UIntArray nbrs = self.nbrs
        cdef NNPS nnps = self.nnps
        cdef ParticleArrayWrapper src, dst

        #######################################################################
        ##  Declare all the arrays.
        #######################################################################
        # Arrays.\
        ${indent(object.get_array_declarations(), 2)}
        #######################################################################
        ## Declare any variables.
        #######################################################################
        # Variables.\

        cdef int src_array_index, dst_array_index
        ${indent(object.get_variable_declarations(), 2)}
        #######################################################################
        ## Iterate over groups:
        ## Groups are organized as {destination: (eqs_with_no_source, sources)}
        ## eqs_with_no_source: Group([equations]) all SPH Equations with no source.
        ## sources are {source: Group([equations...])} 
        #######################################################################
        % for g_idx, group in enumerate(object.groups):
        # Group ${g_idx}.
        #######################################################################
        ## Iterate over destinations in this group.
        #######################################################################
        % for dest, (eqs_with_no_source, sources) in group.iteritems():
        # Destination ${dest}.\
        #######################################################################
        ## Setup destination array pointers.
        #######################################################################

        dst = self.${dest}
        ${indent(object.get_dest_array_setup(dest, eqs_with_no_source, sources), 2)}
        dst_array_index = dst.index

        #######################################################################
        ## Handle all the equations that do not have a source.
        #######################################################################
        % if len(eqs_with_no_source.equations) > 0:
        # SPH Equations with no sources.
        for d_idx in range(NP_DEST):
            ${indent(eqs_with_no_source.get_loop_code(object.kernel), 3)}
        % endif
        #######################################################################
        ## Iterate over sources.
        #######################################################################
        % for source, eq_group in sources.iteritems():
        # Source ${source}.\
        #######################################################################
        ## Setup source array pointers.
        #######################################################################
        
        src = self.${source}
        ${indent(object.get_src_array_setup(source, eq_group), 2)}
        src_array_index = src.index
        
        # Locator.\
        #######################################################################
        ## Create the locator
        #######################################################################
        #${indent(object.get_locator_code(source, dest), 2)}
        #######################################################################
        ## Iterate over destination particles.
        #######################################################################
        for d_idx in range(NP_DEST):
            # Initialize temp vars.\
            ${indent(object.get_initialization(eq_group), 3)}
            ###################################################################
            ## Find and iterate over neighbors.
            ###################################################################
            #locator.get_neighbors(d_idx, nbrs)
            nnps.get_nearest_particles(
                src_array_index, dst_array_index, d_idx, nbrs)

            for nbr_idx in range(nbrs._length):
                s_idx = <int>nbrs.data[nbr_idx]
                ###############################################################
                ## Iterate over the equations for the same set of neighbors.
                ###############################################################
                ${indent(eq_group.get_loop_code(object.kernel), 4)}
            ###################################################################
            ## Do any post neighbor loop assignments.
            ###################################################################
            # Post-loop code.\
            ${indent(eq_group.get_post_loop_code(object.kernel), 3)}
        # Source ${source} done.
        % endfor
        # Destination ${dest} done.
        % endfor
        # Group ${g_idx} done.
        % endfor
        