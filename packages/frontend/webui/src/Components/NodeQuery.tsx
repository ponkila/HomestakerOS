import { useState } from 'react'
import { Text, Button, Box, FormControl, FormLabel, Heading, Input } from '@chakra-ui/react'

const NodeQuery = () => {
  const [nodeResponse, setNodeResponse] = useState('')

  const queryIp = async (e: any) => {
    e.preventDefault()
    const nodeEndpoint = e.target.nodeEndpoint.value
    const nodeResponseJson = await (await fetch(nodeEndpoint)).json()
    setNodeResponse(JSON.stringify(nodeResponseJson, null, 2))
  }

  return (
    <>
      <Box borderWidth="1px" borderRadius="lg" p={4}>
        <Heading as="h2" size="md" mb={4}>
          Node query
        </Heading>
        <form onSubmit={queryIp}>
          <FormControl my={4} id="nodeEndpoint">
            <FormLabel>Node Endpoint</FormLabel>
            <Input placeholder="http://127.0.0.1/" />
          </FormControl>
          <Button w="100%" type="submit">
            Query
          </Button>
        </form>
      </Box>
      <Box borderWidth="1px" borderRadius="lg" p={4} overflow="scroll" mt={4}>
        <Heading as="h2" size="md" mb={4}>
          Response
        </Heading>
        <Text as="pre">{nodeResponse || 'No response yet...'}</Text>
      </Box>
    </>
  )
}

export default NodeQuery
