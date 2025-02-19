import { Container, Box, Heading, Flex, Spacer, Tag, TagLabel } from '@chakra-ui/react'
import { useState, useEffect } from 'react'
import './App.css'
import NewsletterForm from './Components/NewsletterForm'
import { Tabs, TabList, Tab } from '@chakra-ui/react'
import useMetaMask from './Hooks/useMetaMask'
import * as O from 'fp-ts/Option'
import { Outlet, Link } from "react-router-dom";
import { useParams, useLoaderData } from "react-router-dom";
import { useBackend } from './Context/BackendContext'

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

export const Block = async (endpoint: string, timeout: number): Promise<O.Option<Record<string, any>>> => {
  const controller = new AbortController();
  const signal = controller.signal;

  const timeoutId = setTimeout(() => controller.abort(), timeout);
  try {
    const response = await fetch(`${endpoint}/eth/v1/beacon/headers/head`, {
      method: 'GET',
      headers: {
        Accept: 'application/json',
      },
      signal,
    });

    clearTimeout(timeoutId);

    if (!response.ok) {
      throw new Error(`HTTP error! Status: ${response.status}`);
    }

    const data = await response.json();
    return O.some(data);
  } catch (_) {
    return O.none
  }
};



export const TabsView = () => {
  const loader: any = useLoaderData();
  let { owner, repo } = useParams();

  const schema = O.some(loader.schema);
  const flake = loader.flake;

  const { backendUrl } = useBackend();

  return (
    <>
      <Tabs variant="enclosed">
        <TabList mb={5}>
          <Link to={`/${owner}/${repo}#backendUrl=${backendUrl}`}><Tab>Status</Tab></Link>
          <Link to={`/${owner}/${repo}/nixosConfigurations#backendUrl=${backendUrl}`}>
            <Tab isDisabled={O.isNone(schema) ? true : false}>NixOS config</Tab>
          </Link>
          <Link to={`/${owner}/${repo}/query#backendUrl=${backendUrl}`}><Tab>Query node</Tab></Link>
          <Link to={`/${owner}/${repo}/visualize#backendUrl=${backendUrl}`}><Tab>Nodes</Tab></Link>
          <Link to={`/${owner}/${repo}/ssvform#backendUrl=${backendUrl}`}><Tab>Register SSV operator</Tab></Link>
        </TabList>
      </Tabs>
      <Outlet context={[flake, schema]} />
    </>
  );
};

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
        <a href="/">
          <Heading as="h1" size="xl" mb={4} cursor="pointer">
            🪄 HomestakerOS
          </Heading>
        </a>
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
