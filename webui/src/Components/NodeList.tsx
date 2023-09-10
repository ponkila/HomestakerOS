import { useState } from 'react'
import {
  Button,
  Spinner,
  Box,
  Heading,
  List,
  ListItem,
  HStack,
  Text,
  Link,
  Modal,
  ModalOverlay,
  ModalContent,
  ModalHeader,
  ModalBody,
  ModalCloseButton,
} from '@chakra-ui/react'
import { useNodeInfo, NodeInfo } from '../Context/NodeInfoContext'
import ConfigurationForm from './ConfigurationForm'

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
  const nodeInfo = useNodeInfo()

  return (
    <Box borderWidth="1px" w="100%" borderRadius="lg" p={4}>
      <EditConfigModal isOpen={showModal} onClose={() => setShowModal(false)} node={selectedNode} />
      <Heading as="h2" size="md" mb={4}>
        Nodes
      </Heading>
      {nodeInfo.length > 0 && (
        <List>
          {nodeInfo.map((node: NodeInfo) => (
            <ListItem key={node.hostname}>
              <HStack>
                <Heading as="h3" size="sm">
                  {node.hostname}
                </Heading>
                <Button
                  size="xs"
                  isDisabled={!node.config}
                  onClick={() => {
                    setSelectedNode(node)
                    setShowModal(true)
                  }}
                >
                  Edit
                </Button>
                <Text ml={2}>Initrd:</Text>
                {node.hasInitrd ? (
                  <Link href={`/nixosConfigurations/${node.hostname}/result/initrd.zst`}>
                    <Button size="xs">Download</Button>
                  </Link>
                ) : (
                  <Spinner size="xs" color="green.500" />
                )}
                <Text ml={2}>BzImage:</Text>
                {node.hasBzImage ? (
                  <Link href={`/nixosConfigurations/${node.hostname}/result/bzImage`}>
                    <Button size="xs">Download</Button>
                  </Link>
                ) : (
                  <Spinner size="xs" color="green.500" />
                )}
                <Text ml={2}>Kexec:</Text>
                {node.hasKexec ? (
                  <Link href={`/nixosConfigurations/${node.hostname}/result/kexec-boot`}>
                    <Button size="xs">Download</Button>
                  </Link>
                ) : (
                  <Spinner size="xs" color="green.500" />
                )}
              </HStack>
            </ListItem>
          ))}
        </List>
      )}
    </Box>
  )
}
