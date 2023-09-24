import { Container, Box, Heading, Flex, Spacer, Text, Tag, TagLabel } from '@chakra-ui/react'
import { useState, useEffect } from 'react'
import './App.css'
import ConfigurationForm from './Components/ConfigurationForm'
import NewsletterForm from './Components/NewsletterForm'
import NodeQuery from './Components/NodeQuery'
import RegisterSSVForm from './Components/RegisterSSVForm'
import NodeList from './Components/NodeList'
import { Tabs, TabList, TabPanels, Tab, TabPanel } from '@chakra-ui/react'
import useMetaMask from './Hooks/useMetaMask'
import { NodeInfoProvider, fetchNodeConfig } from './Context/NodeInfoContext'
import { StatusPage } from './Components/StatusPage'
import * as O from 'fp-ts/Option'
import { pipe } from 'fp-ts/function'
import { fetchHostnames } from './Context/NodeInfoContext'

const Schema = () => {
  const [schema, setSchema] = useState<O.Option<Record<string, any>>>(O.none)

  useEffect(() => {
    fetch('/schema.json')
      .then((res) => res.json())
      .then((data) => setSchema(O.some(data)))
      .catch((_) => setSchema(O.none))
  }, [])

  return schema
}

export type BlockResponse = {
  host: string;
  data: O.Option<Record<string, any>>;
}

const Block = async (endpoint: string): Promise<O.Option<Record<string, any>>> => {
  const block = await fetch(`${endpoint}/eth/v1/beacon/headers/head`, {
    method: 'GET',
    headers: {
      Accept: 'application/json',
    },
  }).then((res) => res.json())
    .then((data) => O.some(data))
    .catch((_) => O.none)
  return block
}

const Backend = () => {
  const [status, setStatus] = useState<boolean>(false)

  useEffect(() => {
    fetch('http://localhost:8081/api', {
      method: 'GET',
      headers: {
        'Access-Control-Allow-Origin': '*',
        Accept: 'application/json',
        'Content-Type': 'application/json',
      },
    }).then((res) => setStatus(res.ok))
  }, [])

  return status
}

const TabsView = () => {

  const [nodes, setNodes] = useState<Record<string, any>[]>([])
  const [blocks, setBlocks] = useState<Record<string, any>[]>()

  const schema = Schema()

  const refresh = async () => {
    const res = await fetchHostnames();
    const xs = O.getOrElse(() => new Array())(res)

    const nm = await Promise.all(xs.map(async (v, _) => await fetchNodeConfig(v)))
    const nr = nm.map((x) => O.toNullable(x)).flatMap(f => f ? [f] : [])
    setNodes(nr)

    const blocks = await Promise.all(nr.map(async (n) => {
      const data = await Block(n.consensus.lighthouse.endpoint)
      const res: BlockResponse = {
        host: n.localization.hostname,
        data: data,
      }
      return res
    }))
    setBlocks(blocks)
  }

  useEffect(() => {
    refresh()
  }, [])

  const configPage = pipe(
    schema,
    O.match(
      () => <></>,
      (head) => <ConfigurationForm schema={head} nodes={nodes} />
    )
  )

  return (
    <Tabs variant="enclosed">
      <TabList>
        <Tab>Status</Tab>
        <Tab isDisabled={O.isNone(schema) ? true : false}>NixOS config</Tab>
        <Tab>Query node</Tab>
        <Tab>Nodes</Tab>
        <Tab>Register SSV operator</Tab>
      </TabList>
      <TabPanels>
        <TabPanel>
          <StatusPage
            count={schema}
            backend={Backend()}
            nodes={nodes}
            blocks={blocks} />
        </TabPanel>
        <TabPanel>
          {configPage}
        </TabPanel>
        <TabPanel>
          <NodeQuery />
        </TabPanel>
        <TabPanel>
          <NodeList />
        </TabPanel>
        <TabPanel>
          <RegisterSSVForm />
        </TabPanel>
      </TabPanels>
    </Tabs>
  )
}

const App = () => {
  const [hasProvider, wallet, handleConnect] = useMetaMask()

  return (
    <NodeInfoProvider>
      <Container maxW="container.lg">
        <Box position="fixed" top={4} right={4}>
          {wallet.accounts.length > 0 ? (
            <Tag size="lg" colorScheme="green" borderRadius="full" variant="solid" cursor="pointer">
              <TagLabel>
                {wallet.accounts[0].slice(0, 6)}...{wallet.accounts[0].slice(-4)}
              </TagLabel>
            </Tag>
          ) : (
            hasProvider && (
              <Tag
                size="lg"
                colorScheme="blue"
                borderRadius="full"
                variant="solid"
                cursor="pointer"
                onClick={handleConnect}
              >
                <TagLabel>Connect MetaMask</TagLabel>
              </Tag>
            )
          )}
        </Box>
        <Flex mb={8} mt={8}>
          <Heading as="h1" size="xl" mb={4}>
            🪄 HomestakerOS
          </Heading>
          <Text as="i" fontSize="md">
            v.alpha
          </Text>
          <Spacer />
          <NewsletterForm />
        </Flex>
        <Text as="p" align="left">
          HomestakerOS is a web UI which creates custom Linux OS for Ethereum homestaking. It aims to{' '}
          <Text as="b">democratize</Text> homestaking by simplifying the process of creating and maintaining servers in
          home environments.
        </Text>
        <Text as="p" align="left">
          The wizard produces Linux disk images based on NixOS. NixOS allows configurations to be <b>public</b>,{' '}
          <b>deterministic</b>, and <b>self-upgrading</b>. Further, by loading the whole operating system into the RAM,
          we can eliminate the <i>works on my machine</i> tantrum, while also making it possible to be booted by{' '}
          <b>double-clicking</b> a <a href="https://en.wikipedia.org/wiki/Kexec">kernel execution</a> script -- and if
          you want to return to your previous distribution, just restart your computer.
        </Text>
        <Box w="100%" mt={8} mb={8}>
          <TabsView />
        </Box>
      </Container>
    </NodeInfoProvider>
  )
}

export default App
