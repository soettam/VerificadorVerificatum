"""
    ByteTree

Implementación del formato ByteTree de Verificatum para serialización de datos estructurados.

ByteTree es un formato binario usado por Verificatum para representar datos jerárquicos.
Se usa en firmas RSA, pruebas ZKP, y comunicación entre parties.

# Formato Binario

## Leaf (Hoja)
```
[0x01] [4 bytes: length] [data]
```

## Node (Nodo)
```
[0x00] [4 bytes: num_children] [child1] [child2] ... [childN]
```

# Referencias
- Verificatum vcr-3.1.0: com.verificatum.eio.ByteTree
- Documentación: https://www.verificatum.org/files/vmnv-3.0.3.pdf

# Ejemplo
```julia
# Crear un leaf
leaf = ByteTreeLeaf([0x01, 0x02, 0x03])

# Crear un node
node = ByteTreeNode([leaf1, leaf2])

# Serializar
bytes = serialize_bytetree(node)

# Parsear
tree = parse_bytetree(bytes)
```
"""
module ByteTreeModule

export ByteTree, ByteTreeLeaf, ByteTreeNode
export parse_bytetree, serialize_bytetree
export create_bytetree_leaf, create_bytetree_node, bytetree_container
export bytetree_size, bytetree_to_bytes

"""
    ByteTree

Tipo abstracto para representar un ByteTree de Verificatum.

Puede ser:
- `ByteTreeLeaf`: Hoja con datos (bytes)
- `ByteTreeNode`: Nodo con hijos (otros ByteTrees)
"""
abstract type ByteTree end

"""
    ByteTreeLeaf <: ByteTree

Hoja de un ByteTree que contiene datos binarios.

# Campos
- `data::Vector{UInt8}`: Datos binarios de la hoja

# Formato serializado
```
[0x01] [4 bytes: length en big-endian] [data]
```
"""
struct ByteTreeLeaf <: ByteTree
    data::Vector{UInt8}
end

"""
    ByteTreeNode <: ByteTree

Nodo de un ByteTree que contiene otros ByteTrees como hijos.

# Campos
- `children::Vector{ByteTree}`: Hijos del nodo

# Formato serializado
```
[0x00] [4 bytes: num_children en big-endian] [child1] [child2] ... [childN]
```
"""
struct ByteTreeNode <: ByteTree
    children::Vector{ByteTree}
end

# ==================== Construcción de ByteTrees ====================

"""
    create_bytetree_leaf(data::Vector{UInt8}) -> ByteTreeLeaf
    create_bytetree_leaf(data::String) -> ByteTreeLeaf

Crea un ByteTreeLeaf desde datos binarios o un string.

# Argumentos
- `data`: Datos para la hoja (bytes o string UTF-8)

# Retorna
- `ByteTreeLeaf` conteniendo los datos

# Ejemplos
```julia
leaf1 = create_bytetree_leaf([0x01, 0x02, 0x03])
leaf2 = create_bytetree_leaf("Hello")
```
"""
create_bytetree_leaf(data::Vector{UInt8}) = ByteTreeLeaf(data)
create_bytetree_leaf(data::String) = ByteTreeLeaf(Vector{UInt8}(codeunits(data)))

"""
    create_bytetree_node(children::Vector{<:ByteTree}) -> ByteTreeNode

Crea un ByteTreeNode con los hijos especificados.

# Argumentos
- `children`: Vector de ByteTrees hijos (ByteTreeLeaf o ByteTreeNode)

# Retorna
- `ByteTreeNode` conteniendo los hijos

# Ejemplo
```julia
node = create_bytetree_node([leaf1, leaf2, leaf3])
```
"""
create_bytetree_node(children::Vector{<:ByteTree}) = ByteTreeNode(collect(ByteTree, children))

"""
    bytetree_container(trees::ByteTree...) -> ByteTreeNode

Crea un ByteTreeNode contenedor (equivalente a ByteTreeContainer de Java).

Esta es la función principal usada por Verificatum para crear mensajes firmados:
```
fullMessage = bytetree_container(
    create_bytetree_leaf("party_id/label"),
    create_bytetree_leaf(data)
)
```

# Argumentos
- `trees`: ByteTrees a incluir en el contenedor

# Retorna
- `ByteTreeNode` conteniendo todos los árboles

# Ejemplo
```julia
prefix = create_bytetree_leaf("3/PublicKey")
data = create_bytetree_leaf(file_content)
full_message = bytetree_container(prefix, data)
```
"""
bytetree_container(trees::ByteTree...) = create_bytetree_node(collect(trees))

# ==================== Serialización ====================

"""
    serialize_bytetree(tree::ByteTree) -> Vector{UInt8}

Serializa un ByteTree al formato binario de Verificatum.

# Formato Leaf
```
[0x01] [4 bytes: length] [data]
```

# Formato Node
```
[0x00] [4 bytes: num_children] [serialized_child1] [serialized_child2] ...
```

# Argumentos
- `tree`: ByteTree a serializar

# Retorna
- Vector de bytes con la representación serializada

# Ejemplo
```julia
tree = create_bytetree_leaf("Hello")
bytes = serialize_bytetree(tree)
# bytes = [0x01, 0x00, 0x00, 0x00, 0x05, 0x48, 0x65, 0x6c, 0x6c, 0x6f]
```
"""
function serialize_bytetree(tree::ByteTreeLeaf)::Vector{UInt8}
    result = UInt8[]
    
    # Tag: 0x01 para leaf
    push!(result, 0x01)
    
    # Length: 4 bytes big-endian
    length_value = UInt32(length(tree.data))
    push!(result, UInt8((length_value >> 24) & 0xff))
    push!(result, UInt8((length_value >> 16) & 0xff))
    push!(result, UInt8((length_value >> 8) & 0xff))
    push!(result, UInt8(length_value & 0xff))
    
    # Data
    append!(result, tree.data)
    
    return result
end

function serialize_bytetree(tree::ByteTreeNode)::Vector{UInt8}
    result = UInt8[]
    
    # Tag: 0x00 para node
    push!(result, 0x00)
    
    # Number of children: 4 bytes big-endian
    num_children = UInt32(length(tree.children))
    push!(result, UInt8((num_children >> 24) & 0xff))
    push!(result, UInt8((num_children >> 16) & 0xff))
    push!(result, UInt8((num_children >> 8) & 0xff))
    push!(result, UInt8(num_children & 0xff))
    
    # Serialize each child recursively
    for child in tree.children
        append!(result, serialize_bytetree(child))
    end
    
    return result
end

"""
    bytetree_to_bytes(tree::ByteTree) -> Vector{UInt8}

Alias para `serialize_bytetree`. Serializa un ByteTree a bytes.
"""
bytetree_to_bytes(tree::ByteTree) = serialize_bytetree(tree)

# ==================== Parsing ====================

"""
    parse_bytetree(data::Vector{UInt8}, offset::Int=1) -> (ByteTree, Int)

Parsea un ByteTree desde datos binarios.

# Formato esperado
- Leaf: `[0x01] [4 bytes: length] [data]`
- Node: `[0x00] [4 bytes: num_children] [child1] [child2] ...`

# Argumentos
- `data`: Datos binarios a parsear
- `offset`: Posición inicial en el array (1-indexed)

# Retorna
- Tupla `(tree, next_offset)` donde:
  - `tree`: ByteTree parseado
  - `next_offset`: Siguiente posición después del árbol

# Errores
- Lanza `ArgumentError` si el formato es inválido

# Ejemplo
```julia
bytes = [0x01, 0x00, 0x00, 0x00, 0x05, 0x48, 0x65, 0x6c, 0x6c, 0x6f]
tree, next_pos = parse_bytetree(bytes)
# tree = ByteTreeLeaf([0x48, 0x65, 0x6c, 0x6c, 0x6f])  # "Hello"
```
"""
function parse_bytetree(data::Vector{UInt8}, offset::Int=1)::Tuple{ByteTree, Int}
    if offset > length(data)
        throw(ArgumentError("Offset $offset fuera de rango (data length: $(length(data)))"))
    end
    
    # Leer tag (0x00 = node, 0x01 = leaf)
    tag = data[offset]
    offset += 1
    
    if tag == 0x01
        # Leaf: [0x01] [4 bytes length] [data]
        return parse_bytetree_leaf(data, offset)
    elseif tag == 0x00
        # Node: [0x00] [4 bytes num_children] [children...]
        return parse_bytetree_node(data, offset)
    else
        throw(ArgumentError("Tag ByteTree inválido: 0x$(string(tag, base=16, pad=2)) en offset $(offset-1)"))
    end
end

"""
    parse_bytetree_leaf(data::Vector{UInt8}, offset::Int) -> (ByteTreeLeaf, Int)

Parsea un ByteTreeLeaf desde la posición actual (después del tag 0x01).

# Formato
```
[4 bytes: length en big-endian] [data]
```
"""
function parse_bytetree_leaf(data::Vector{UInt8}, offset::Int)::Tuple{ByteTreeLeaf, Int}
    # Leer length (4 bytes big-endian)
    if offset + 3 > length(data)
        throw(ArgumentError("Datos insuficientes para leer length del leaf"))
    end
    
    length_bytes = data[offset:offset+3]
    data_length = Int(ntoh(reinterpret(UInt32, length_bytes)[1]))
    offset += 4
    
    # Leer data
    if offset + data_length - 1 > length(data)
        throw(ArgumentError("Datos insuficientes para leer $data_length bytes del leaf"))
    end
    
    leaf_data = data[offset:offset+data_length-1]
    offset += data_length
    
    return (ByteTreeLeaf(leaf_data), offset)
end

"""
    parse_bytetree_node(data::Vector{UInt8}, offset::Int) -> (ByteTreeNode, Int)

Parsea un ByteTreeNode desde la posición actual (después del tag 0x00).

# Formato
```
[4 bytes: num_children en big-endian] [child1] [child2] ... [childN]
```
"""
function parse_bytetree_node(data::Vector{UInt8}, offset::Int)::Tuple{ByteTreeNode, Int}
    # Leer num_children (4 bytes big-endian)
    if offset + 3 > length(data)
        throw(ArgumentError("Datos insuficientes para leer num_children del node"))
    end
    
    num_children_bytes = data[offset:offset+3]
    num_children = Int(ntoh(reinterpret(UInt32, num_children_bytes)[1]))
    offset += 4
    
    # Parsear cada hijo recursivamente
    children = ByteTree[]
    for i in 1:num_children
        child, offset = parse_bytetree(data, offset)
        push!(children, child)
    end
    
    return (ByteTreeNode(children), offset)
end

# ==================== Utilidades ====================

"""
    bytetree_size(tree::ByteTree) -> Int

Calcula el tamaño en bytes de la representación serializada de un ByteTree.

# Argumentos
- `tree`: ByteTree del que calcular el tamaño

# Retorna
- Tamaño en bytes

# Ejemplo
```julia
leaf = create_bytetree_leaf("Hello")
size = bytetree_size(leaf)  # 10 bytes: [0x01][4 bytes length][5 bytes data]
```
"""
function bytetree_size(tree::ByteTreeLeaf)::Int
    # Tag (1 byte) + Length (4 bytes) + Data
    return 1 + 4 + length(tree.data)
end

function bytetree_size(tree::ByteTreeNode)::Int
    # Tag (1 byte) + NumChildren (4 bytes) + Sum of children sizes
    return 1 + 4 + sum(bytetree_size(child) for child in tree.children)
end

"""
    Base.show(io::IO, tree::ByteTreeLeaf)

Muestra una representación legible de un ByteTreeLeaf.
"""
function Base.show(io::IO, tree::ByteTreeLeaf)
    data_preview = if length(tree.data) <= 32
        "[" * join(string.(tree.data, base=16, pad=2), " ") * "]"
    else
        preview = join(string.(tree.data[1:16], base=16, pad=2), " ")
        "[" * preview * " ... ($(length(tree.data)) bytes total)]"
    end
    print(io, "ByteTreeLeaf($(length(tree.data)) bytes): $data_preview")
end

"""
    Base.show(io::IO, tree::ByteTreeNode)

Muestra una representación legible de un ByteTreeNode.
"""
function Base.show(io::IO, tree::ByteTreeNode)
    print(io, "ByteTreeNode($(length(tree.children)) children, $(bytetree_size(tree)) bytes total)")
end

"""
    Base.:(==)(a::ByteTreeLeaf, b::ByteTreeLeaf) -> Bool

Compara dos ByteTreeLeaf por igualdad.
"""
Base.:(==)(a::ByteTreeLeaf, b::ByteTreeLeaf) = a.data == b.data

"""
    Base.:(==)(a::ByteTreeNode, b::ByteTreeNode) -> Bool

Compara dos ByteTreeNode por igualdad (recursivamente).
"""
Base.:(==)(a::ByteTreeNode, b::ByteTreeNode) = a.children == b.children

end # module ByteTreeModule
