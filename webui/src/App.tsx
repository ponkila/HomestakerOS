import { Container, Box, Heading, Flex, Spacer, Tag, TagLabel } from '@chakra-ui/react'
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
import { FlakeSection } from './Components/Flake'

const Schema = (flake: string) => {
  const [schema, setSchema] = useState<O.Option<Record<string, any>>>(O.none)

  useEffect(() => {
    fetch(`${flake}/nixosModules/homestakeros/options.json`)
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

const TabsView = (props: any) => {

  const [nodes, setNodes] = useState<Record<string, any>[]>([])
  const [blocks, setBlocks] = useState<Record<string, any>[]>()

  const schema = Schema(props.flake)

  const refresh = async (props: any) => {
    const res = await fetchHostnames(props.flake);
    const xs = O.getOrElse(() => new Array())(res)

    const nm = await Promise.all(xs.map(async (v, _) => await fetchNodeConfig(props.flake, v)))
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
    refresh(props)
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
  const [flake, setFlake] = useState<O.Option<string>>(O.none)

  const panel = pipe(flake, O.match(
    () => <FlakeSection setter={setFlake} />,
    (x) => <TabsView flake={x} />,
  ))

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
          <Spacer />
          <NewsletterForm />
        </Flex>
        <Box w="100%" mt={8} mb={8}>
          {panel}
        </Box>
      </Container>
    </NodeInfoProvider>
  )
}

export default App
