import { Button, Spinner, Box, Heading, List, ListItem, HStack, Text, Link } from '@chakra-ui/react'
import { useNodeInfo, NodeInfo } from '../Context/NodeInfoContext'

export default function NodeList() {
  const nodeInfo = useNodeInfo()

  return (
    <Box borderWidth="1px" w="100%" borderRadius="lg" p={4}>
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
                <Text ml={2}>Initrd:</Text>
                {node.hasInitrd ? (
                  <Link href={`/nixosConfigurations/${node.hostname}/initrd.zst`}>
                    <Button size="xs">Download</Button>
                  </Link>
                ) : (
                  <Spinner size="xs" color="green.500" />
                )}
                <Text ml={2}>BzImage:</Text>
                {node.hasBzImage ? (
                  <Link href={`/nixosConfigurations/${node.hostname}/bzImage`}>
                    <Button size="xs">Download</Button>
                  </Link>
                ) : (
                  <Spinner size="xs" color="green.500" />
                )}
                <Text ml={2}>Kexec:</Text>
                {node.hasKexec ? (
                  <Link href={`/nixosConfigurations/${node.hostname}/kexec-boot`}>
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
