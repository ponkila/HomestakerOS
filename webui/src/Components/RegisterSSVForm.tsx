import { useState } from 'react'
import { Text, Button, Box, FormControl, FormLabel, Heading, Input, Spinner, Link, Select, AlertIcon, Alert } from '@chakra-ui/react'
import { ExternalLinkIcon } from '@chakra-ui/icons'
import { ethers } from 'ethers/dist/ethers.esm.js'
import useMetaMask from '../Hooks/useMetaMask'
import { useNodeInfo, NodeInfo } from '../Context/NodeInfoContext'
import { parseEther } from "viem";

const enum ContractAddresses {
  Testnet = "0x38A4794cCEd47d3baf7370CcC43B560D3a1beEFA",
  Mainnet = "0xDD9BC35aE942eF0cFa76930954a156B3fF30a4E1",
}
const BLOCKS_PER_YEAR = 2613400n;
const USE_TEST_NET = true;

const RegisterSSVForm = () => {
  const [hasProvider, wallet, handleConnect] = useMetaMask()
  const [isLoading, setIsLoading] = useState(false)
  const [error, setError] = useState('')
  const [transactionLink, setTransactionLink] = useState('')
  const [_, setNode] = useState<NodeInfo | null>(null)
  const nodeInfo = useNodeInfo()

  const registerOperator = async (e: any) => {
    e.preventDefault();
    setIsLoading(true);
    setTransactionLink('');
    try {
      const coder = new ethers.utils.AbiCoder();

      const pk = e.target.publicKey.value;
      const fee = roundOperatorFee(parseEther(e.target.fee.value) / BLOCKS_PER_YEAR);
      const setPrivate = e.target.isPrivate.checked;
      const provider = new ethers.providers.Web3Provider(window.ethereum);
      const signer = provider.getSigner();

      const abi = await (await fetch('/SSVNetwork.json')).json();
      const address = USE_TEST_NET ? ContractAddresses.Testnet : ContractAddresses.Mainnet
      const contract = new ethers.Contract(address, abi, signer);
      const gasEstimate = await contract.estimateGas.registerOperator(coder.encode(['string'], [pk]), fee, setPrivate);
      const pkDecoded = ethers.utils.base64.decode(pk);
      const publicKeyBytes = ethers.utils.arrayify(pkDecoded);
      contract
        .registerOperator(publicKeyBytes, fee, setPrivate, { gasLimit: gasEstimate })
        .then((tx: any) => {
          setIsLoading(false);
          setError('');
          const txLink = USE_TEST_NET ? `https://holesky.etherscan.io/tx/${tx.hash}` : `https://etherscan.io/tx/${tx.hash}`;
          setTransactionLink(txLink)
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

  const roundOperatorFee = (
    fee: bigint,
    precision = 10_000_000n,
  ): bigint => {
    return bigintRound(fee, precision);
  }

  const bigintRound = (value: bigint, precision: bigint): bigint => {
    const remainder = value % precision;
    return remainder >= precision / 2n
      ? value + (precision - remainder) // Round up
      : value - remainder; // Round down
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
              <FormControl my={4} id="publicKey" isRequired>
                <FormLabel>Public key</FormLabel>
                <Input />
              </FormControl>
              <FormControl my={4} id="fee">
                <FormLabel>Fee</FormLabel>
                <Input type="number" max="200" min="0" step="any" placeholder="1.0" />
              </FormControl>
              <FormControl my={4} id="isPrivate">
                <FormLabel>Private Operator</FormLabel>
                <input type="checkbox" name="isPrivate" />
              </FormControl>

              {transactionLink && (
                <Alert mb={5} status="success">
                  <AlertIcon />
                  Transaction submitted!
                  <Link ml={1} href={transactionLink} color="blue.500" isExternal>
                    View Transaction
                  </Link>
                </Alert>
              )}
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
