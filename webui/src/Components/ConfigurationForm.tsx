import React, { useState, useEffect } from 'react'
import {
  Spacer,
  Collapse,
  Button,
  Box,
  Checkbox,
  Flex,
  FormControl,
  FormLabel,
  FormHelperText,
  Heading,
  Input,
  OrderedList,
  ListItem,
  NumberInput,
  NumberInputField,
  NumberInputStepper,
  NumberIncrementStepper,
  NumberDecrementStepper,
  Tooltip,
} from '@chakra-ui/react'
import { QuestionOutlineIcon } from '@chakra-ui/icons'
import { AddIcon, CloseIcon } from '@chakra-ui/icons'
import * as jp from 'jsonpath'

const FormSection = (props: { name: string | undefined; children: React.ReactNode }) => {
  const { name, children } = props
  const [show, setShow] = useState(true)
  return (
    <Box mb={4} borderWidth="1px" borderRadius="lg" p={4} pb={1}>
      <Flex onClick={() => setShow(!show)} cursor="pointer">
        {name && (
          <Heading as="h3" size="sm" mb={4}>
            {name}
          </Heading>
        )}
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

const DescriptionFormLabel = (props: { label: string | undefined; description: string | null }) => {
  const { label, description } = props
  if (description == null) return <FormLabel>{label}</FormLabel>
  else
    return (
      <FormLabel>
        {label && <>{label}</>}
        <Tooltip label={description} aria-label="A tooltip">
          <QuestionOutlineIcon ml={2} />
        </Tooltip>
      </FormLabel>
    )
}

type ListOfControlProps = {
  nodeKey: string
  description: string | null
  example: string | null
  defaultValue: string[] | null
}

const ListOfControl = (props: ListOfControlProps) => {
  const { nodeKey, description, example, defaultValue } = props
  const [list, setList] = useState<string[]>(defaultValue || [])
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

const CustomCheckbox = (props: { name: string; checked: boolean; children?: React.ReactNode }) => {
  const { name, children } = props
  return (
    <>
      <Input name={name} type="hidden" value="0" />
      <Checkbox value="1" {...props}>
        {children && <>{children}</>}
      </Checkbox>
    </>
  )
}

type AttrsOfControlProps = {
  keys: string[]
  description: string | null
  example: Record<string, string | boolean> | null
  defaultValue: Record<string, any> | null
}

const AttrsOfControl = (props: AttrsOfControlProps) => {
  const { keys, description, example, defaultValue } = props
  const [list, setList] = useState<string[]>(Object.keys(defaultValue || {}))
  if (!example) return <></>
  const name = keys.slice(-1)[0]
  const fields = Object.values(example)[0]

  return (
    <FormSection name={name}>
      <FormControl>
        {list.map((item, i) => (
          <FormSection name={`${item}`}>
            <Flex mb={2} direction="column">
              <FormControl mr={4} mb={4} isRequired>
                <FormLabel>name</FormLabel>
                <Input
                  placeholder="Name"
                  onChange={(e) => {
                    setList(list.map((v, j) => (j == i ? e.target.value : v)))
                  }}
                />
              </FormControl>
              {Object.entries(fields).map(([key, value]) => (
                <FormControl mr={4} mb={4}>
                  <FormLabel>{key}</FormLabel>
                  {typeof value == 'boolean' ? (
                    <CustomCheckbox name={jp.stringify([...keys, item, key])} checked={value} />
                  ) : (
                    <Input placeholder={value} name={jp.stringify([...keys, item, key])} />
                  )}
                </FormControl>
              ))}
              <Button as={CloseIcon} onClick={() => setList(list.filter((_, j) => j != i))} />
            </Flex>
          </FormSection>
        ))}
        <Button as={AddIcon} onClick={() => setList([...list, ''])} />
        <FormHelperText>{description}</FormHelperText>
      </FormControl>
    </FormSection>
  )
}

const ConfigurationForm = () => {
  const [schema, setSchema] = useState<Record<string, any>>({})

  const isLeaf = (node: Record<string, any>) => {
    return node != null && node.constructor == Object && 'type' in node
  }

  const processNode = (keys: string[], node: Record<string, any>) => {
    const keyName = keys.at(-1)
    const jsonPath = jp.stringify(keys)
    if (isLeaf(node)) {
      switch (node.type) {
        case 'bool':
          return (
            <FormControl id={jsonPath}>
              <DescriptionFormLabel label={keyName} description={node.description} />
              <CustomCheckbox name={jsonPath} checked={node.default}>
                {keyName}
              </CustomCheckbox>
            </FormControl>
          )
          break
        case 'str':
        case 'path':
        case 'nullOr':
          return (
            <FormControl id={jsonPath}>
              <DescriptionFormLabel label={keyName} description={node.description} />
              <Input name={jsonPath} defaultValue={node.default} />
              {node.example && <FormHelperText>Example: {node.example}</FormHelperText>}
            </FormControl>
          )
          break
        case 'int':
          return (
            <FormControl id={jsonPath}>
              <DescriptionFormLabel label={keyName} description={node.description} />
              <NumberInput name={jsonPath} defaultValue={node.default}>
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
            <AttrsOfControl
              keys={keys}
              description={node.description}
              example={node.example}
              defaultValue={node.default}
            />
          )
          break
        case 'listOf':
          return (
            <ListOfControl
              nodeKey={jsonPath}
              description={node.description}
              example={node.example}
              defaultValue={node.default}
            />
          )
          break
        default:
          break
      }
      if (node.type.startsWith('strMatching')) {
        return (
          <FormControl>
            <FormLabel>{keyName}</FormLabel>
            <Input name={jsonPath} placeholder={node.default} />
            <FormHelperText>{node.description}</FormHelperText>
          </FormControl>
        )
      }
    } else {
      return (
        <FormSection name={keyName}>
          {Object.entries(node).map(([newKey, value]) => {
            return processNode([...keys, newKey], value)
          })}
        </FormSection>
      )
    }
  }

  useEffect(() => {
    fetch('/schema.json')
      .then((res) => res.json())
      .then((data) => {
        setSchema(data)
      })
  }, [])

  const recursiveReplace = (obj: any) => {
    if ('default' in obj) {
      return obj['default']
    }
    for (const key in obj) {
      obj[key] = recursiveReplace(obj[key])
    }
    return obj
  }

  const handleSubmit = (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault()
    const result = recursiveReplace(structuredClone(schema))
    const formData = new FormData(e.target as HTMLFormElement)
    const formDataJson = Object.fromEntries(formData.entries())
    Object.entries(formDataJson).forEach(([key, value]) => {
      const schemaEntry = jp.query(schema, key)
      if (schemaEntry.length > 0 && schemaEntry[0]['type'] == 'int') {
        jp.apply(result, key, () => parseInt(value as string))
      } else if (schemaEntry.length > 0 && schemaEntry[0]['type'] == 'bool') {
        jp.apply(result, key, () => value === '1')
      } else if (schemaEntry.length == 0) {
        let parent = null
        let parentPath = ''
        for (let i = 1; i < key.length; i++) {
          parentPath = jp.stringify(
            jp
              .parse(key)
              .slice(0, -i)
              .map((v: any) => v['expression']['value'])
          )
          parent = jp.query(schema, parentPath)
          if (parent.length > 0) {
            parent = parent[0]
            break
          }
        }
        if (parent['type'] == 'listOf') {
          jp.apply(result, parentPath, (v: any) => [...v, value])
        } else if (parent['type'] == 'attrsOf') {
          const path = jp.parse(key).at(-2)['expression']['value']
          const objPath = jp.stringify([...jp.parse(parentPath).map((v: any) => v['expression']['value']), path])
          const obj = jp.query(result, objPath)
          if (obj.length == 0) {
            jp.apply(result, parentPath, (v: any) => ({ ...v, [path]: {} }))
          }
          const key2 = jp.parse(key).at(-1)['expression']['value']
          if (key2 == 'enable') {
            jp.apply(result, objPath, (v: any) => ({ ...v, [key2]: value === '1' }))
          } else {
            jp.apply(result, objPath, (v: any) => ({ ...v, [key2]: value }))
          }
        }
      } else {
        jp.apply(result, key, () => value)
      }
    })
    console.log(JSON.stringify(result, null, 2))
    fetch('http://localhost:8081/api/nixosConfig', {
      method: 'POST',
      headers: {
        'Access-Control-Allow-Origin': '*',
        Accept: 'application/json',
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(result),
      mode: 'cors',
    })
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
      {processNode(['$'], structuredClone(schema))}
      <Button w="100%" type="submit">
        #BUIDL
      </Button>
    </form>
  )
}

export default ConfigurationForm
