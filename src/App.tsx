import { Container, Box, Heading, Flex, Spacer, Text, Tag, TagLabel } from '@chakra-ui/react'
import './App.css'
import ConfigurationForm from './ConfigurationForm'
import NewsletterForm from './NewsletterForm'
import NodeQuery from './NodeQuery'
import RegisterSSVForm from './RegisterSSVForm'
import { Tabs, TabList, TabPanels, Tab, TabPanel } from '@chakra-ui/react'
import useMetaMask from './useMetaMask'

const TabsView = () => {
  return (
    <Tabs variant="enclosed">
      <TabList>
        <Tab>NixOS config</Tab>
        <Tab>Query node</Tab>
        <Tab>Register SSV operator</Tab>
      </TabList>
      <TabPanels>
        <TabPanel>
          <ConfigurationForm />
        </TabPanel>
        <TabPanel>
          <NodeQuery />
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
        <b>deterministic</b>, and <b>self-upgrading</b>. Further, by loading the whole operating system into the RAM, we
        can eliminate the <i>works on my machine</i> tantrum, while also making it possible to be booted by{' '}
        <b>double-clicking</b> a <a href="https://en.wikipedia.org/wiki/Kexec">kernel execution</a> script -- and if you
        want to return to your previous distribution, just restart your computer.
      </Text>
      <Box w="100%" mt={8} mb={8}>
        <TabsView />
      </Box>
    </Container>
  )
}

export default App
