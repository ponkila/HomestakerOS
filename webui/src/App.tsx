import { Container, Box, Heading, Flex, Spacer, Tag, TagLabel } from '@chakra-ui/react'
import { useState, useEffect } from 'react'
import './App.css'
import NewsletterForm from './Components/NewsletterForm'
import { Tabs, TabList, Tab } from '@chakra-ui/react'
import useMetaMask from './Hooks/useMetaMask'
import * as O from 'fp-ts/Option'
import { Outlet, Link } from "react-router-dom";
import { useParams, useLoaderData } from "react-router-dom";

export const Schema = (flake: string) => {
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

export const Block = async (endpoint: string): Promise<O.Option<Record<string, any>>> => {
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

export const TabsView = () => {

  const loader: any = useLoaderData();
  let { owner, repo } = useParams();

  const schema = O.some(loader.schema)
  const flake = loader.flake

  return (
    <>
      <Tabs variant="enclosed">
        <TabList>
          <Link to={`/${owner}/${repo}`}><Tab>Status</Tab></Link>
          <Link to={`/${owner}/${repo}/nixosConfigurations`}><Tab isDisabled={O.isNone(schema) ? true : false}>NixOS config</Tab></Link>
          <Link to={`/${owner}/${repo}/query`}><Tab>Query node</Tab></Link>
          <Link to={`/${owner}/${repo}/visualize`}><Tab>Nodes</Tab></Link>
          <Link to={`/${owner}/${repo}/ssvform`}><Tab>Register SSV operator</Tab></Link>
        </TabList>
      </Tabs >
      <Outlet context={[flake, schema]} />
    </>
  )
}

export const App = () => {
  const [hasProvider, wallet, handleConnect] = useMetaMask()

  return (
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
        <Outlet />
      </Box>
    </Container>
  )
}

export default App
