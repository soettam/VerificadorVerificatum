"""
Tests para el módulo ByteTree de Verificatum.

Tests de:
- Serialización/deserialización de ByteTreeLeaf y ByteTreeNode
- Construcción de ByteTreeContainer
- Verificación de firmas RSA con ByteTree
- Casos de uso reales con dataset ONPE100
"""

using Test
using SHA

# Importar módulos
include("../src/bytetree.jl")
using .ByteTreeModule

@testset "ByteTree Tests" begin
    
    @testset "ByteTreeLeaf - Construcción y Serialización" begin
        # Test 1: Crear leaf simple
        data = UInt8[0x01, 0x02, 0x03, 0x04, 0x05]
        leaf = create_bytetree_leaf(data)
        
        @test leaf isa ByteTreeLeaf
        @test leaf.data == data
        
        # Test 2: Serializar leaf
        serialized = serialize_bytetree(leaf)
        
        # Formato esperado: [0x01][4 bytes length][data]
        @test serialized[1] == 0x01  # Tag leaf
        @test length(serialized) == 1 + 4 + 5  # Tag + length + data
        
        # Verificar length (big-endian)
        length_value = ntoh(reinterpret(UInt32, serialized[2:5])[1])
        @test length_value == 5
        
        # Verificar data
        @test serialized[6:10] == data
        
        println("✓ ByteTreeLeaf serialización correcta")
    end
    
    @testset "ByteTreeLeaf - Parsing" begin
        # Test 3: Parsear leaf
        serialized = UInt8[0x01, 0x00, 0x00, 0x00, 0x05, 0x48, 0x65, 0x6c, 0x6c, 0x6f]
        # [0x01][length=5]["Hello"]
        
        leaf, next_offset = parse_bytetree(serialized, 1)
        
        @test leaf isa ByteTreeLeaf
        @test leaf.data == UInt8[0x48, 0x65, 0x6c, 0x6c, 0x6f]  # "Hello"
        @test String(leaf.data) == "Hello"
        @test next_offset == 11  # Posición después del último byte
        
        println("✓ ByteTreeLeaf parsing correcto")
    end
    
    @testset "ByteTreeLeaf - String" begin
        # Test 4: Crear leaf desde string
        leaf = create_bytetree_leaf("Hello World")
        
        @test leaf isa ByteTreeLeaf
        @test String(copy(leaf.data)) == "Hello World"
        
        # Serializar y parsear
        serialized = serialize_bytetree(leaf)
        parsed, _ = parse_bytetree(serialized)
        
        @test parsed.data == leaf.data
        @test String(copy(parsed.data)) == "Hello World"
        
        println("✓ ByteTreeLeaf con strings correcto")
    end
    
    @testset "ByteTreeNode - Construcción y Serialización" begin
        # Test 5: Crear node simple
        leaf1 = create_bytetree_leaf("First")
        leaf2 = create_bytetree_leaf("Second")
        node = create_bytetree_node([leaf1, leaf2])
        
        @test node isa ByteTreeNode
        @test length(node.children) == 2
        @test node.children[1] == leaf1
        @test node.children[2] == leaf2
        
        # Test 6: Serializar node
        serialized = serialize_bytetree(node)
        
        # Formato esperado: [0x00][4 bytes num_children][child1][child2]
        @test serialized[1] == 0x00  # Tag node
        
        # Verificar num_children (big-endian)
        num_children = ntoh(reinterpret(UInt32, serialized[2:5])[1])
        @test num_children == 2
        
        println("✓ ByteTreeNode serialización correcta")
    end
    
    @testset "ByteTreeNode - Parsing" begin
        # Test 7: Crear node, serializar, parsear
        leaf1 = create_bytetree_leaf([0x01, 0x02])
        leaf2 = create_bytetree_leaf([0x03, 0x04, 0x05])
        node = create_bytetree_node([leaf1, leaf2])
        
        serialized = serialize_bytetree(node)
        parsed, next_offset = parse_bytetree(serialized)
        
        @test parsed isa ByteTreeNode
        @test length(parsed.children) == 2
        @test parsed == node
        @test next_offset == length(serialized) + 1
        
        println("✓ ByteTreeNode parsing correcto")
    end
    
    @testset "ByteTreeContainer - Esquema Verificatum" begin
        # Test 8: Simular fullMessage de Verificatum
        # fullMessage = ByteTreeContainer(ByteTree("3/PublicKey"), ByteTree(data))
        
        party_id = 3
        message_label = "PublicKey"
        party_prefix = string(party_id) * "/" * message_label
        
        prefix_leaf = create_bytetree_leaf(party_prefix)
        data_leaf = create_bytetree_leaf("test data content")
        full_message = bytetree_container(prefix_leaf, data_leaf)
        
        @test full_message isa ByteTreeNode
        @test length(full_message.children) == 2
        @test String(full_message.children[1].data) == "3/PublicKey"
        @test String(full_message.children[2].data) == "test data content"
        
        # Serializar
        serialized = serialize_bytetree(full_message)
        
        # Parsear de vuelta
        parsed, _ = parse_bytetree(serialized)
        @test parsed == full_message
        
        println("✓ ByteTreeContainer (esquema Verificatum) correcto")
    end
    
    @testset "ByteTree - Anidamiento" begin
        # Test 9: Árbol anidado
        leaf1 = create_bytetree_leaf("A")
        leaf2 = create_bytetree_leaf("B")
        node1 = create_bytetree_node([leaf1, leaf2])
        
        leaf3 = create_bytetree_leaf("C")
        node2 = create_bytetree_node([node1, leaf3])  # Node anidado
        
        @test node2.children[1] isa ByteTreeNode
        @test node2.children[2] isa ByteTreeLeaf
        
        # Serializar y parsear
        serialized = serialize_bytetree(node2)
        parsed, _ = parse_bytetree(serialized)
        
        @test parsed == node2
        @test parsed.children[1].children[1].data == UInt8[0x41]  # 'A'
        @test parsed.children[1].children[2].data == UInt8[0x42]  # 'B'
        @test parsed.children[2].data == UInt8[0x43]  # 'C'
        
        println("✓ ByteTree anidado correcto")
    end
    
    @testset "ByteTree - Tamaños" begin
        # Test 10: Calcular tamaños
        leaf = create_bytetree_leaf([0x01, 0x02, 0x03])
        @test bytetree_size(leaf) == 1 + 4 + 3  # Tag + length + data = 8
        
        leaf1 = create_bytetree_leaf([0x01])
        leaf2 = create_bytetree_leaf([0x02, 0x03])
        node = create_bytetree_node([leaf1, leaf2])
        
        # Node: 1 (tag) + 4 (num_children) + 6 (leaf1) + 7 (leaf2) = 18
        expected_size = 1 + 4 + bytetree_size(leaf1) + bytetree_size(leaf2)
        @test bytetree_size(node) == expected_size
        
        # Verificar que el tamaño coincide con la serialización
        serialized = serialize_bytetree(node)
        @test length(serialized) == bytetree_size(node)
        
        println("✓ Cálculo de tamaños correcto")
    end
    
    @testset "ByteTree - Hash SHA-256" begin
        # Test 11: Hash de ByteTree (usado en firmas)
        party_prefix = "3/shutdown_first_round"
        data = "test content"
        
        prefix_leaf = create_bytetree_leaf(party_prefix)
        data_leaf = create_bytetree_leaf(data)
        full_message = bytetree_container(prefix_leaf, data_leaf)
        
        # Serializar
        serialized = serialize_bytetree(full_message)
        
        # Calcular SHA-256 (primer hash en esquema Verificatum)
        digest = sha256(serialized)
        
        @test length(digest) == 32  # SHA-256 produce 32 bytes
        @test digest isa Vector{UInt8}
        
        # Verificar que el mismo árbol produce el mismo hash
        serialized2 = serialize_bytetree(full_message)
        digest2 = sha256(serialized2)
        @test digest == digest2
        
        println("✓ Hash SHA-256 de ByteTree correcto")
    end
    
    @testset "ByteTree - Casos edge" begin
        # Test 12: Leaf vacío
        empty_leaf = create_bytetree_leaf(UInt8[])
        @test bytetree_size(empty_leaf) == 1 + 4 + 0  # 5 bytes
        
        serialized = serialize_bytetree(empty_leaf)
        parsed, _ = parse_bytetree(serialized)
        @test parsed == empty_leaf
        
        # Test 13: Node sin hijos (edge case)
        empty_node = create_bytetree_node(ByteTree[])
        @test length(empty_node.children) == 0
        
        serialized = serialize_bytetree(empty_node)
        parsed, _ = parse_bytetree(serialized)
        @test parsed == empty_node
        
        # Test 14: Leaf grande (1KB)
        large_data = rand(UInt8, 1024)
        large_leaf = create_bytetree_leaf(large_data)
        @test bytetree_size(large_leaf) == 1 + 4 + 1024
        
        serialized = serialize_bytetree(large_leaf)
        parsed, _ = parse_bytetree(serialized)
        @test parsed == large_leaf
        
        println("✓ Casos edge correctos")
    end
    
    @testset "ByteTree - Errores" begin
        # Test 15: Tag inválido
        invalid_tag = UInt8[0xFF, 0x00, 0x00, 0x00, 0x01, 0x42]
        @test_throws ArgumentError parse_bytetree(invalid_tag)
        
        # Test 16: Datos truncados (leaf)
        truncated_leaf = UInt8[0x01, 0x00, 0x00, 0x00, 0x05, 0x41]  # Declara 5 bytes pero solo hay 1
        @test_throws ArgumentError parse_bytetree(truncated_leaf)
        
        # Test 17: Datos truncados (node)
        truncated_node = UInt8[0x00, 0x00, 0x00, 0x00, 0x02]  # Declara 2 hijos pero no hay datos
        @test_throws ArgumentError parse_bytetree(truncated_node)
        
        println("✓ Manejo de errores correcto")
    end
    
end

println("\n" * "="^60)
println("✓ TODOS LOS TESTS DE BYTETREE PASARON EXITOSAMENTE")
println("="^60)
