import { useState } from 'react'
import { Text, Button, Box, FormControl, FormLabel, Heading, Input, Spinner, Link, Select } from '@chakra-ui/react'
import { ExternalLinkIcon } from '@chakra-ui/icons'
import { ethers } from 'ethers/dist/ethers.esm.js'
import useMetaMask from '../Hooks/useMetaMask'
import { useNodeInfo, NodeInfo } from '../Context/NodeInfoContext'

const RegisterSSVForm = () => {
  const [hasProvider, wallet, handleConnect] = useMetaMask()
  const [isLoading, setIsLoading] = useState(false)
  const [error, setError] = useState('')
  const [node, setNode] = useState<NodeInfo | null>(null)
  const nodeInfo = useNodeInfo()

  const registerOperator = async (e: any) => {
    e.preventDefault();
    setIsLoading(true);

    try {
      const coder = new ethers.utils.AbiCoder();

      const pk = e.target.publicKey.value;
      const fee = Number(e.target.fee.value);
      const setPrivate = e.target.isPrivate.checked;
      const provider = new ethers.providers.Web3Provider(window.ethereum);
      const signer = provider.getSigner();

      const abi = await (await fetch('/SSVNetwork.json')).json();
      const contract = new ethers.Contract("0x38A4794cCEd47d3baf7370CcC43B560D3a1beEFA", abi, signer);
      const gasEstimate = await contract.estimateGas.registerOperator(coder.encode(['string'], [pk]), fee, setPrivate);
      const pkDecoded = ethers.utils.base64.decode(pk);
      const publicKeyBytes = ethers.utils.arrayify(pkDecoded);
      contract
        .registerOperator(publicKeyBytes, fee, setPrivate, { gasLimit: gasEstimate })
        .then((tx: any) => {
          console.log(tx);
          setIsLoading(false);
          setError('');
        })
    } catch (err: any) {
      setError(err.message);
      setIsLoading(false);
    }
  };

  const onHostnameChange = (e: any) => {
    if (e.target.value) {
      setNode(e.target.value)
    } else {
      setNode(null)
    }
  }

  return (
    <>
      {error && (
        <Box bg="tomato" borderWidth="1px" w="100%" borderRadius="lg" color="white" my={4} p={4}>
          <Text>{error}</Text>
        </Box>
      )}
      <Box borderWidth="1px" w="100%" borderRadius="lg" p={4}>
        <Heading as="h2" size="md" mb={4}>
          Register SSV operator
        </Heading>
        {!hasProvider ? (
          <Link href="https://metamask.io/download" isExternal>
            <Button>
              Install MetaMask <ExternalLinkIcon mx="2px" />
            </Button>
          </Link>
        ) : (
          wallet.accounts.length === 0 && <Button onClick={handleConnect}>Connect to MetaMask</Button>
        )}
        {hasProvider &&
          wallet.accounts.length > 0 &&
          (isLoading ? (
            <Spinner />
          ) : (
            <form onSubmit={registerOperator}>
              <FormControl my={4}>
                <FormLabel>Owner</FormLabel>
                <Input disabled value={wallet.accounts[0] || ''} />
              </FormControl>
              <FormControl my={4}>
                <FormLabel>Hostname</FormLabel>
                <Select placeholder="Select hostname" onChange={onHostnameChange}>
                  {nodeInfo.map((node: NodeInfo) => (
                    <option key={node.hostname} value={node.hostname}>{node.hostname}</option>
                  ))}
                </Select>
              </FormControl>
              <FormControl my={4} id="publicKey">
                <FormLabel>Public key</FormLabel>
                <Input
                // value={getOrElse(() => "No public key available")(node?.ssvKey ?? O.none)}
                />
              </FormControl>
              <FormControl my={4} id="fee">
                <FormLabel>Fee</FormLabel>
                <Input placeholder="1.0" />
              </FormControl>
              <FormControl my={4} id="isPrivate">
                <FormLabel>Private Operator</FormLabel>
                <input type="checkbox" name="isPrivate" />
              </FormControl>
              <Button w="100%" type="submit">
                Register
              </Button>

            </form>
          ))}
      </Box>
    </>
  )
}

export default RegisterSSVForm
