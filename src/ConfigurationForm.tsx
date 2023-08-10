import React, { useState, useEffect } from 'react'
import {
  Text,
  Spacer,
  Collapse,
  Button,
  Box,
  Checkbox,
  CheckboxGroup,
  Flex,
  FormControl,
  FormLabel,
  FormErrorMessage,
  FormHelperText,
  Heading,
  Input,
  OrderedList,
  ListItem,
  Select,
  Slider,
  SliderTrack,
  SliderFilledTrack,
  SliderThumb,
  SliderMark,
  NumberInput,
  NumberInputField,
  NumberInputStepper,
  NumberIncrementStepper,
  NumberDecrementStepper,
  Tooltip,
} from '@chakra-ui/react'
import { QuestionIcon } from '@chakra-ui/icons'
import { AddIcon, CloseIcon } from '@chakra-ui/icons'

const FormSection = (props: { name: string; children: React.ReactNode }) => {
  const { name, children } = props
  const [show, setShow] = useState(true)
  return (
    <Box mb={4} borderWidth="1px" borderRadius="lg" p={4} pb={1}>
      <Flex onClick={() => setShow(!show)} cursor="pointer">
        <Heading as="h3" size="sm" mb={4}>
          {name}
        </Heading>
        <Spacer />
        <Button size="xs" onClick={() => setShow(!show)}>
          {show ? 'Hide' : 'Show'}
        </Button>
      </Flex>
      <Collapse in={show} animateOpacity>
        {children}
      </Collapse>
    </Box>
  )
}

const DescriptionFormLabel = (props: { label: string; description: string | null }) => {
  const { label, description } = props
  if (description == null) return <FormLabel>{label}</FormLabel>
  else
    return (
      <FormLabel>
        {label}
        <Tooltip label={description} aria-label="A tooltip">
          <QuestionIcon ml={2} />
        </Tooltip>
      </FormLabel>
    )
}

type ListOfControlProps = {
  nodeKey: string
  description: string | null
  example: string | null
  default: string[] | null
}

const ListOfControl = (props: ListOfControlProps) => {
  const {
    nodeKey,
    description,
    example,
    default: [],
  } = props
  const [list, setList] = useState<string[]>([])
  const name = nodeKey.split('.').slice(-1)[0]

  return (
    <>
      <FormControl id={name}>
        <DescriptionFormLabel label={name} description={description} />
        {list.map((item, i) => (
          <Flex mb={2}>
            <Input
              name={`${nodeKey}[${i}]`}
              value={item}
              key={i}
              placeholder={item}
              onChange={(e) => setList(list.map((v, j) => (j == i ? e.target.value : v)))}
            />
            <Button ml={4} as={CloseIcon} onClick={() => setList(list.filter((_, j) => j != i))} />
          </Flex>
        ))}
        <Button as={AddIcon} onClick={() => setList([...list, ''])} />
        {example && <FormHelperText>Example: {example}</FormHelperText>}
      </FormControl>
    </>
  )
}

const ConfigurationForm = () => {
  const [sliderValue, setSliderValue] = useState(1)
  const [schema, setSchema] = useState<Record<string, any>>({})

  const isLeaf = (node: Record<string, any>) => {
    return node != null && node.constructor == Object && 'type' in node
  }

  const processNode = (key: string, node: Record<string, any>) => {
    const keyName = key.split('.').slice(-1)[0]
    if (isLeaf(node)) {
      switch (node.type) {
        case 'bool':
          return (
            <FormControl id={key}>
              <DescriptionFormLabel label={keyName} description={node.description} />
              <Checkbox name={key} checked={node.default}>
                {keyName}
              </Checkbox>
            </FormControl>
          )
          break
        case 'str':
        case 'path':
        case 'nullOr':
          return (
            <FormControl id={key}>
              <DescriptionFormLabel label={keyName} description={node.description} />
              <Input name={key} value={node.default} />
              {node.example && <FormHelperText>Example: {node.example}</FormHelperText>}
            </FormControl>
          )
          break
        case 'int':
          return (
            <FormControl id={key}>
              <DescriptionFormLabel label={keyName} description={node.description} />
              <NumberInput name={key} defaultValue={node.default}>
                <NumberInputField />
                <NumberInputStepper>
                  <NumberIncrementStepper />
                  <NumberDecrementStepper />
                </NumberInputStepper>
              </NumberInput>
              {node.example && <FormHelperText>Example: {node.example}</FormHelperText>}
            </FormControl>
          )
          break
        case 'attrsOf':
          return (
            <FormSection name={keyName}>
              <FormControl>
                <Flex>
                  <FormControl mr={4}>
                    <Input placeholder="What" />
                  </FormControl>
                  <FormControl mr={4}>
                    <Input placeholder="Where" />
                  </FormControl>
                  <FormControl mr={4}>
                    <Input placeholder="Options" />
                  </FormControl>
                  <FormControl>
                    <Input placeholder="Type" />
                  </FormControl>
                </Flex>
                <FormHelperText>{node.description}</FormHelperText>
              </FormControl>
            </FormSection>
          )
          break
        case 'listOf':
          return (
            <ListOfControl nodeKey={key} description={node.description} example={node.example} default={node.default} />
          )
          break
        default:
          break
      }
      if (node.type.startsWith('strMatching')) {
        return (
          <FormControl>
            <FormLabel>{keyName}</FormLabel>
            <Input name={key} placeholder={node.default} />
            <FormHelperText>{node.description}</FormHelperText>
          </FormControl>
        )
      }
    } else {
      return (
        <FormSection name={keyName}>
          {Object.entries(node).map(([newKey, value]) => {
            return processNode(`${key}.${newKey}`, value)
          })}
        </FormSection>
      )
    }
  }

  useEffect(() => {
    fetch('/public/schema.json')
      .then((res) => res.json())
      .then((data) => {
        setSchema(data)
      })
  }, [])

  const handleSubmit = (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault()
    const formData = new FormData(e.target)
    const formDataJson = Object.fromEntries(formData.entries())
    console.log(formDataJson)
  }

  return (
    <form onSubmit={handleSubmit}>
      <Box borderWidth="1px" borderRadius="lg" p={4} mb={4}>
        <Heading as="h2" size="md" mb={4}>
          Configuration
        </Heading>
        <OrderedList>
          <ListItem>Select features below</ListItem>
          <ListItem>Click on #BUIDL</ListItem>
          <ListItem>A download will start for your initrd and kernel</ListItem>
          <ListItem>
            Execute the <a href="https://en.wikipedia.org/wiki/Kexec">kexec</a> script on an existing Linux distribution
            to boot
          </ListItem>
        </OrderedList>
      </Box>
      {processNode('$', schema)}
      <Button w="100%" type="submit">
        #BUIDL
      </Button>
    </form>
  )
}

export default ConfigurationForm
