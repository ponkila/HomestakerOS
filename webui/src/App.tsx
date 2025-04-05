import { Container, Box, Heading, Flex, Spacer, Tag, TagLabel, Text } from '@chakra-ui/react'
import { useState, useEffect } from 'react'
import './App.css'
import NewsletterForm from './Components/NewsletterForm'
import { Tabs, TabList, Tab } from '@chakra-ui/react'
import useMetaMask from './Hooks/useMetaMask'
import * as O from 'fp-ts/Option'
import { Outlet, Link, useLocation } from "react-router-dom";
import { useParams, useLoaderData } from "react-router-dom";
import { useBackend } from './Context/BackendContext'
import NetworkSwitchBtn from './Components/NetworkSwitchBtn'

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
  host: string
  data: O.Option<Record<string, any>>
}

export const Block = async (endpoint: string, timeout: number): Promise<O.Option<Record<string, any>>> => {
  const controller = new AbortController()
  const signal = controller.signal

  const timeoutId = setTimeout(() => controller.abort(), timeout)
  try {
    const response = await fetch(`${endpoint}/eth/v1/beacon/headers/head`, {
      method: 'GET',
      headers: {
        Accept: 'application/json',
      },
      signal,
    })

    clearTimeout(timeoutId)

    if (!response.ok) {
      throw new Error(`HTTP error! Status: ${response.status}`)
    }

    const data = await response.json()
    return O.some(data)
  } catch (_) {
    return O.none
  }
}

export const TabsView = () => {
  const loader: any = useLoaderData();
  let { owner, repo } = useParams();
  const location = useLocation();
  const { backendUrl } = useBackend();

  const schema = O.some(loader.schema)
  const flake = loader.flake

  const getActiveTabIndex = () => {
    if (location.pathname.includes("nixosConfigurations")) return 1;
    if (location.pathname.includes("query")) return 2;
    if (location.pathname.includes("visualize")) return 3;
    if (location.pathname.includes("ssvform")) return 4;
    return 0;
  };

  return (
    <>
      <Tabs sx={{ borderBottom: "none" }} index={getActiveTabIndex()}>
        <TabList mb={5} sx={{ borderBottom: "none" }}>
          <Link to={`/${owner}/${repo}#backendUrl=${backendUrl}`}><Tab _focus={{ outline: "none"}}>Status</Tab></Link>
          <Link to={`/${owner}/${repo}/nixosConfigurations#backendUrl=${backendUrl}`}>
            <Tab isDisabled={O.isNone(schema)} _focus={{ outline: "none" }}>NixOS config</Tab>
          </Link>
          <Link to={`/${owner}/${repo}/query#backendUrl=${backendUrl}`}><Tab _focus={{ outline: "none"}}>Query node</Tab></Link>
          <Link to={`/${owner}/${repo}/visualize#backendUrl=${backendUrl}`}><Tab _focus={{ outline: "none"}}>Nodes</Tab></Link>
          <Link to={`/${owner}/${repo}/ssvform#backendUrl=${backendUrl}`}><Tab _focus={{ outline: "none"}}>Register SSV operator</Tab></Link>
        </TabList>
      </Tabs>
      <Outlet context={[flake, schema]} />
    </>
  )
}

export const App = () => {
  const [hasProvider, wallet, handleConnect, switchNetwork] = useMetaMask()

  return (
    <Container maxW="container.lg">
      <Box position="fixed" top={4} right={4}>
        {!hasProvider ? (
          <Text>MetaMask is not available. Please install MetaMask.</Text>
        ) : (
          <>
            {wallet.accounts.length > 0 ? (
              <Box>
                <NetworkSwitchBtn wallet={wallet} switchNetwork={switchNetwork} handleConnect={handleConnect} />
              </Box>
            ) : (
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
            )}
          </>
        )}
      </Box>
      <Flex mb={8} mt={8}>
        <Flex direction="column">
          <Link to="/">
            <Heading as="h1" size="xl" mb={2} cursor="pointer">
              🪄 HomestakerOS
            </Heading>
          </Link>
          <Link
            to="https://github.com/ponkila/HomestakerOS/blob/main/docs/homestakeros/1-introduction.md"
            target="_blank"
            rel="noopener noreferrer"
          >
            <Text fontSize="lg" color="blue.500" textAlign="center" _hover={{ textDecoration: 'underline' }}>
              Documentation
            </Text>
          </Link>
        </Flex>
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
