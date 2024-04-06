import { useState, useEffect } from 'react'
import 'reactflow/dist/style.css'
import ReactFlow, { useNodesState, useEdgesState, Controls, Background, Node, Edge } from 'reactflow'
import NixNode from './Flow/NixNode'
import {
  Box,
  Heading,
  Modal,
  ModalOverlay,
  ModalContent,
  ModalHeader,
  ModalBody,
  ModalCloseButton,
} from '@chakra-ui/react'
import { useNodeInfo, NodeInfo } from '../Context/NodeInfoContext'
import ConfigurationForm from './ConfigurationForm'

const initialNodes: Node[] = []
const initialEdges: Edge[] = []
const nodeTypes = {
  nixNode: NixNode,
}

const EditConfigModal = ({
  isOpen,
  onClose,
  node,
}: {
  isOpen: boolean
  onClose: () => void
  node: NodeInfo | null
}) => {
  if (!node) {
    return null
  }
  return (
    <Modal isOpen={isOpen} onClose={onClose} size="4xl" scrollBehavior="inside" blockScrollOnMount={false}>
      <ModalOverlay />
      <ModalContent>
        <ModalHeader>Edit "{node.hostname}"</ModalHeader>
        <ModalCloseButton />
        <ModalBody>
          <ConfigurationForm schema={node.config} />
        </ModalBody>
      </ModalContent>
    </Modal>
  )
}

export default function NodeList() {
  const [showModal, setShowModal] = useState(false)
  const [selectedNode, setSelectedNode] = useState<NodeInfo | null>(null)
  const [nodes, setNodes, onNodesChange] = useNodesState(initialNodes)
  const [edges, setEdges, onEdgesChange] = useEdgesState(initialEdges)
  const nodeInfo = useNodeInfo()

  useEffect(() => {
    const wgNode = {
      id: 'wg',
      type: 'default',
      position: { x: ((nodeInfo.length - 1) * 300) / 2, y: 0 },
      data: { label: 'WireGuard' },
      style: { fontSize: '1.5rem' },
    }
    const newNodes = nodeInfo.map((node, i) => ({
      id: node.hostname,
      type: 'nixNode',
      position: { x: i * 300, y: 100 },
      data: { label: node.config?.localization.hostname || node.hostname, nodeInfo: node, onClick: onNodeClick },
    }))

    const newEdges = nodeInfo.map((node) => ({
      id: `${node.hostname}-wg`,
      target: node.hostname,
      source: 'wg',
      animated: true,
      arrowHeadType: 'arrowclosed',
    }))
    setNodes([wgNode, ...newNodes])
    setEdges(newEdges)
  }, [nodeInfo])

  const onNodeClick = (node: NodeInfo) => {
    if (node) {
      setSelectedNode(node)
      setShowModal(true)
    }
  }

  return (
    <Box borderWidth="1px" w="100%" h="40rem" borderRadius="lg" p={4}>
      <EditConfigModal isOpen={showModal} onClose={() => setShowModal(false)} node={selectedNode} />
      <Heading as="h2" size="md" mb={4}>
        Nodes
      </Heading>
      <Box w="100%" h="90%">
        <ReactFlow
          nodes={nodes}
          edges={edges}
          onNodesChange={onNodesChange}
          onEdgesChange={onEdgesChange}
          nodeTypes={nodeTypes}
          fitView
        >
          <Background />
          <Controls />
        </ReactFlow>
      </Box>
    </Box>
  )
}
