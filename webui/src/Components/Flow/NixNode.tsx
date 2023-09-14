import { useState } from 'react'
import { Handle, Position, NodeProps } from 'reactflow'
import { Link, Button, Box, Text, Collapse } from '@chakra-ui/react'

function NixNode({ data }: NodeProps) {
  const [isOpen, setIsOpen] = useState(false)
  const nodeInfo = data.nodeInfo
  return (
    <>
      <Handle type="target" position={Position.Top} />
      <Box p={2} bg="gray.100" borderRadius="md" boxShadow="md" textAlign="center">
        <Text fontSize="sm" fontWeight="bold">
          {data.label}
          <Button isDisabled={!nodeInfo.config} size="xs" ml={2} onClick={() => data.onClick(nodeInfo)}>
            Edit
          </Button>
        </Text>
        <Link href={`/nixosConfigurations/${nodeInfo.hostname}/result/initrd.zst`}>
          <Button size="xs" isDisabled={!nodeInfo.hasInitrd}>
            initrd
          </Button>
        </Link>
        <Link href={`/nixosConfigurations/${nodeInfo.hostname}/result/bzImage`}>
          <Button size="xs" isDisabled={!nodeInfo.hasBzImage}>
            BzImage
          </Button>
        </Link>
        <Link href={`/nixosConfigurations/${nodeInfo.hostname}/result/kexec-boot`}>
          <Button size="xs" isDisabled={!nodeInfo.hasBzImage}>
            kexec
          </Button>
        </Link>
        <Text fontSize="xs">
          Endpoints
          <Button size="xs" ml={2} onClick={() => setIsOpen(!isOpen)}>
            {isOpen ? 'Hide' : 'Show'}
          </Button>
        </Text>
        <Collapse in={isOpen} animateOpacity>
          {nodeInfo.config?.consensus && (
            <Text fontSize="xs" fontWeight="bold">
              Consensus
            </Text>
          )}
          {nodeInfo.config?.consensus &&
            Object.entries(nodeInfo.config.consensus).map(([key, value]: [string, any]) => (
              <Text key={key} fontSize="xs">
                {key}: {value.endpoint}
              </Text>
            ))}
          {nodeInfo.config?.execution && (
            <Text fontSize="xs" fontWeight="bold">
              Execution
            </Text>
          )}
          {nodeInfo.config?.execution &&
            Object.entries(nodeInfo.config.execution).map(([key, value]: [string, any]) => (
              <Text key={key} fontSize="xs">
                {key}: {value.endpoint}
              </Text>
            ))}
        </Collapse>
      </Box>
      <Handle type="source" position={Position.Bottom} id="a" />
    </>
  )
}

export default NixNode
