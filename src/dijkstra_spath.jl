# Dijkstra's algorithm for single-source shortest path

###################################################################
#
#   The type that capsulates the states of Dijkstra algorithm
#
###################################################################

type DijkstraStates{V,D<:Number,Heap,H}
    parents::Vector{V}
    dists::Vector{D}
    colormap::Vector{Int}
    heap::Heap
    hmap::Vector{H}
end

type DijkstraStates2{V,D<:Number,Heap,H}
    parents::Vector{V}
    dists::Vector{D}
    dists2::Vector{D}
    colormap::Vector{Int}
    heap::Heap
    hmap::Vector{H}
end

immutable DijkstraHEntry{V,D}
    vertex::V
    dist::D
end
< (e1::DijkstraHEntry, e2::DijkstraHEntry) = e1.dist < e2.dist

immutable DijkstraHEntry2{V,D}
    vertex::V
    dist::D
    dist2::D
end
< (e1::DijkstraHEntry2, e2::DijkstraHEntry2) = e1.dist < e2.dist

# create Dijkstra states

function create_dijkstra_states{V,D<:Number}(g::AbstractGraph{V}, ::Type{D})
    n = num_vertices(g)
    parents = Array(V, n)
    dists = fill(typemax(D), n)
    colormap = zeros(Int, n)
    heap = mutable_binary_minheap(DijkstraHEntry{V,D})
    hmap = zeros(Int, n)

    DijkstraStates(parents, dists, colormap, heap, hmap)
end

function create_dijkstra_states2{V,D<:Number}(g::AbstractGraph{V}, ::Type{D})
    n = num_vertices(g)
    parents = Array(V, n)
    dists = fill(typemax(D), n)
    dists2 = fill(typemax(D), n)
    colormap = zeros(Int, n)
    heap = mutable_binary_minheap(DijkstraHEntry2{V,D})
    hmap = zeros(Int, n)

    DijkstraStates2(parents, dists, dists2, colormap, heap, hmap)
end

###################################################################
#
#   visitors
#
###################################################################

abstract AbstractDijkstraVisitor

# invoked when a new vertex is first encountered
discover_vertex!(visitor::AbstractDijkstraVisitor, u, v, d) = nothing

# invoked when the distance of a vertex is determined
# (for each source vertex at the beginning, and when a vertex is popped from the heap)
# returns whether the algorithm should continue
include_vertex!(visitor::AbstractDijkstraVisitor, u, v, d) = true

# invoked when the distance to a vertex is updated (decreased)
update_vertex!(visitor::AbstractDijkstraVisitor, u, v, d) = nothing

# invoked when all neighbors of a vertex has been examined
close_vertex!(visitor::AbstractDijkstraVisitor, v) = nothing


# trivial visitor

type TrivialDijkstraVisitor <: AbstractDijkstraVisitor
end


# log visitor

type LogDijkstraVisitor <: AbstractDijkstraVisitor
    io::IO
end

function discover_vertex!(visitor::LogDijkstraVisitor, u, v, d)
    println(visitor.io, "discover vertex $v (parent = $u, dist = $d)")
end

function include_vertex!(visitor::LogDijkstraVisitor, u, v, d)
    println(visitor.io, "include vertex $v (parent = $u, dist = $d)")
    true
end

function update_vertex!(visitor::LogDijkstraVisitor, u, v, d)
    println(visitor.io, "update distance $v (parent = $u, dist = $d)")
end

function close_vertex!(visitor::LogDijkstraVisitor, v)
    println(visitor.io, "close vertex $v")
end


###################################################################
#
#   core algorithm implementation
#
###################################################################

function set_source!{V,D}(state::DijkstraStates{V,D}, g::AbstractGraph{V}, s::V)
    i = vertex_index(s, g)
    state.parents[i] = s
    state.dists[i] = 0
    state.colormap[i] = 2
end

function set_source2!{V,D}(state::DijkstraStates2{V,D}, g::AbstractGraph{V}, s::V)
    i = vertex_index(s, g)
    state.parents[i] = s
    state.dists[i] = 0
    state.dists2[i] = 0
    state.colormap[i] = 2
end

function process_neighbors!{V,D,Heap,H}(
    state::DijkstraStates{V,D,Heap,H},
    graph::AbstractGraph{V},
    edge_dists::AbstractEdgePropertyInspector{D},
    u::V, du::D, visitor::AbstractDijkstraVisitor)

    dists::Vector{D} = state.dists
    parents::Vector{V} = state.parents
    colormap::Vector{Int} = state.colormap
    heap::Heap = state.heap
    hmap::Vector{H} = state.hmap
    dv::D = zero(D)

    for e in out_edges(u, graph)
        v::V = target(e, graph)
        iv::Int = vertex_index(v, graph)
        v_color::Int = colormap[iv]

        if v_color == 0
            dists[iv] = dv = du + edge_property(edge_dists, e, graph)
            parents[iv] = u
            colormap[iv] = 1
            discover_vertex!(visitor, u, v, dv)

            # push new vertex to the heap
            hmap[iv] = push!(heap, DijkstraHEntry(v, dv))

        elseif v_color == 1
            dv = du + edge_property(edge_dists, e, graph)
            if dv < dists[iv]
                dists[iv] = dv
                parents[iv] = u

                # update the value on the heap
                update_vertex!(visitor, u, v, dv)
                update!(heap, hmap[iv], DijkstraHEntry(v, dv))
            end
        end
    end
end

function process_neighbors!{V,D,Heap,H}(
    state::DijkstraStates2{V,D,Heap,H},
    graph::AbstractGraph{V},
    edge_dists::AbstractEdgePropertyInspector{D},
    edge_dists2::AbstractEdgePropertyInspector{D},
    u::V, du::D, du2::D, visitor::AbstractDijkstraVisitor)

    dists::Vector{D} = state.dists
    dists2::Vector{D} = state.dists2
    parents::Vector{V} = state.parents
    colormap::Vector{Int} = state.colormap
    heap::Heap = state.heap
    hmap::Vector{H} = state.hmap
    dv::D = zero(D)

    for e in out_edges(u, graph)
        v::V = target(e, graph)
        iv::Int = vertex_index(v, graph)
        v_color::Int = colormap[iv]

        if v_color == 0
            dists[iv] = dv = du + edge_property(edge_dists, e, graph)
            dists2[iv] = dv2 = du2 + edge_property(edge_dists2, e, graph) # TODO: Update function
            parents[iv] = u
            colormap[iv] = 1
            discover_vertex!(visitor, u, v, dv)

            # push new vertex to the heap
            hmap[iv] = push!(heap, DijkstraHEntry2(v, dv, dv2))

        elseif v_color == 1
            dv = du + edge_property(edge_dists, e, graph)
            dv2 = du2 + edge_property(edge_dists, e, graph)
            if dv < dists[iv]
                dists[iv] = dv
                dists2[iv] = dv2
                parents[iv] = u

                # update the value on the heap
                update_vertex!(visitor, u, v, dv)
                update!(heap, hmap[iv], DijkstraHEntry2(v, dv, dv2))
            end
        end
    end
end


function dijkstra_shortest_paths!{V, D, Heap, H}(
    graph::AbstractGraph{V},                # the graph
    edge_dists::AbstractEdgePropertyInspector{D}, # distances associated with edges
    sources::AbstractVector{V},             # the sources
    visitor::AbstractDijkstraVisitor,       # visitor object
    state::DijkstraStates{V,D,Heap,H})      # the states

    @graph_requires graph incidence_list vertex_map vertex_list
    edge_property_requirement(edge_dists, graph)

    # get state fields

    parents::Vector{V} = state.parents
    dists::Vector{D} = state.dists
    colormap::Vector{Int} = state.colormap
    heap::Heap = state.heap
    hmap::Vector{H} = state.hmap

    # initialize for sources

    d0 = zero(D)

    for s in sources
        set_source!(state, graph, s)
        if !include_vertex!(visitor, s, s, d0)
            return state
        end
    end

    # process direct neighbors of all sources

    for s in sources
        process_neighbors!(state, graph, edge_dists, s, d0, visitor)
        close_vertex!(visitor, s)
    end

    # main loop

    while !isempty(heap)

        # pick next vertex to include
        entry = pop!(heap)
        u::V = entry.vertex
        du::D = entry.dist

        ui = vertex_index(u, graph)
        colormap[ui] = 2
        if !include_vertex!(visitor, parents[ui], u, du)
            return state
        end

        # process u's neighbors

        process_neighbors!(state, graph, edge_dists, u, du, visitor)
        close_vertex!(visitor, u)
    end

    state
end


function dijkstra_shortest_paths!{V, D, Heap, H}(
    graph::AbstractGraph{V},                # the graph
    edge_dists::AbstractEdgePropertyInspector{D}, # primary distances associated with edges (for planning)
    edge_dists2::AbstractEdgePropertyInspector{D}, # secondary distances associated with edges (for cutting off routes)
    sources::AbstractVector{V},             # the sources
    visitor::AbstractDijkstraVisitor,       # visitor object
    state::DijkstraStates2{V,D,Heap,H})      # the states

    @graph_requires graph incidence_list vertex_map vertex_list
    edge_property_requirement(edge_dists, graph)

    # get state fields

    parents::Vector{V} = state.parents
    dists::Vector{D} = state.dists
    dists2::Vector{D} = state.dists2
    colormap::Vector{Int} = state.colormap
    heap::Heap = state.heap
    hmap::Vector{H} = state.hmap

    # initialize for sources

    d0 = zero(D)
    d02 = zero(D)

    for s in sources
        set_source2!(state, graph, s)
        if !include_vertex!(visitor, s, s, d02)
            return state
        end
    end

    # process direct neighbors of all sources

    for s in sources
        process_neighbors!(state, graph, edge_dists, edge_dists2, s, d0, d02, visitor)
        close_vertex!(visitor, s)
    end

    # main loop

    while !isempty(heap)

        # pick next vertex to include
        entry = pop!(heap)
        u::V = entry.vertex
        du::D = entry.dist
        du2::D = entry.dist2

        ui = vertex_index(u, graph)
        colormap[ui] = 2
        if !include_vertex!(visitor, parents[ui], u, du2)
            return state
        end

        # process u's neighbors

        process_neighbors!(state, graph, edge_dists, edge_dists2, u, du, du2, visitor)
        close_vertex!(visitor, u)
    end

    state
end


function dijkstra_shortest_paths{V, D}(
    graph::AbstractGraph{V},                # the graph
    edge_len::AbstractEdgePropertyInspector{D}, # distances associated with edges
    sources::AbstractVector{V};
    visitor::AbstractDijkstraVisitor=TrivialDijkstraVisitor())
    state = create_dijkstra_states(graph, D)
    dijkstra_shortest_paths!(graph, edge_len, sources, visitor, state)
end


# Convenient functions

function dijkstra_shortest_paths{V,D}(
    graph::AbstractGraph{V}, edge_dists::Vector{D}, s::V;
    visitor::AbstractDijkstraVisitor=TrivialDijkstraVisitor())

    edge_len::AbstractEdgePropertyInspector{D} = VectorEdgePropertyInspector(edge_dists)
    state = create_dijkstra_states(graph, D)
    dijkstra_shortest_paths!(graph, edge_len, [s], visitor, state)
end

function dijkstra_shortest_paths{V,D}(
    graph::AbstractGraph{V}, edge_dists::Vector{D}, edge_dists2::Vector{D}, s::V;
    visitor::AbstractDijkstraVisitor=TrivialDijkstraVisitor())

    edge_len::AbstractEdgePropertyInspector{D} = VectorEdgePropertyInspector(edge_dists)
    edge_len2::AbstractEdgePropertyInspector{D} = VectorEdgePropertyInspector(edge_dists2)
    state = create_dijkstra_states2(graph, D)
    dijkstra_shortest_paths!(graph, edge_len, edge_len2, [s], visitor, state)
end

function dijkstra_shortest_paths{V,D}(
    graph::AbstractGraph{V}, edge_dists::Vector{D}, sources::AbstractVector{V};
    visitor::AbstractDijkstraVisitor=TrivialDijkstraVisitor())

    edge_len::AbstractEdgePropertyInspector{D} = VectorEdgePropertyInspector(edge_dists)
    state = create_dijkstra_states(graph, D)
    dijkstra_shortest_paths!(graph, edge_len, sources, visitor, state)
end

function dijkstra_shortest_paths_withlog{V,D}(
    graph::AbstractGraph{V}, edge_dists::Vector{D}, s::V)
    dijkstra_shortest_paths(graph, edge_dists, s, visitor=LogDijkstraVisitor(STDOUT))
end


function dijkstra_shortest_paths_withlog{V,D}(
    graph::AbstractGraph{V}, edge_dists::Vector{D}, sources::AbstractVector{V})
    dijkstra_shortest_paths(graph, edge_dists, sources, visitor=LogDijkstraVisitor(STDOUT))
end

