import React, { useState } from 'react'
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
  Select,
  AlertIcon,
  AlertTitle,
  AlertDescription,
  VStack,
  Spinner,
  Alert,
  Text
} from '@chakra-ui/react'
import { QuestionOutlineIcon } from '@chakra-ui/icons'
import { AddIcon, CloseIcon } from '@chakra-ui/icons'
import * as jp from 'jsonpath'
import { useLoaderData, useOutletContext } from "react-router-dom";
import { useBackend } from "../Context/BackendContext";
import ArtifactsList, { Artifact } from './ArtifactsList'

let uuid = () => self.crypto.randomUUID();

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
          <Flex key={i} mb={2}>
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

const CustomCheckbox = (props: { name: string; defaultChecked: boolean; children?: React.ReactNode }) => {
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


const isLeaf = (node: Record<string, any>) => {
  return node != null && node.constructor == Object && 'type' in node
}

const processNode = (keys: string[], node: Record<string, any>, sel: Record<string, any>) => {
  const keyName = keys.at(-1)
  const jsonPath = jp.stringify(keys)
  if (isLeaf(node)) {
    if (keys.indexOf("nodes") == 0) {
      const k = jsonPath.replace("nodes", "")
      const s = jp.value(sel, k)
      node.default = s
    }

    switch (true) {
      case node.type.startsWith('bool'):
        return (
          <FormControl key={uuid()} id={jsonPath}>
            <DescriptionFormLabel label={keyName} description={node.description} />
            <CustomCheckbox name={jsonPath} defaultChecked={node.default}>
              {keyName}
            </CustomCheckbox>
          </FormControl>
        )
      case node.type.startsWith('str'):
      case node.type.startsWith('path'):
      case node.type.startsWith('nullOr'):
        return (
          <FormControl key={uuid()} id={jsonPath}>
            <DescriptionFormLabel label={keyName} description={node.description} />
            <Input name={jsonPath} placeholder={node.example} defaultValue={node.default} />
          </FormControl>
        )
      case node.type.startsWith('int'):
        return (
          <FormControl key={uuid()} id={jsonPath}>
            <DescriptionFormLabel label={keyName} description={node.description} />
            <NumberInput name={jsonPath} defaultValue={node.default}>
              <NumberInputField />
              <NumberInputStepper>
                <NumberIncrementStepper />
                <NumberDecrementStepper />
              </NumberInputStepper>
            </NumberInput>
          </FormControl>
        )
      case node.type.startsWith('attrsOf'):
        return (
          <AttrsOfControl
            key={uuid()}
            keys={keys}
            description={node.description}
            example={node.example}
            defaultValue={node.default}
            options={node.options}
            sel={sel}
          />
        )
      case node.type.startsWith('listOf'):
        return (
          <ListOfControl
            key={uuid()}
            nodeKey={jsonPath}
            description={node.description}
            example={node.example}
            defaultValue={node.default}
          />
        )
      default:
        break
    }
    if (node.type.startsWith('strMatching')) {
      return (
        <FormControl key={uuid()}>
          <DescriptionFormLabel label={keyName} description={node.description} />
          <Input name={jsonPath} placeholder={node.example} defaultValue={node.default} />
          <FormHelperText>{node.description}</FormHelperText>
        </FormControl>
      )
    }
  } else {
    return (
      <FormSection key={uuid()} name={keyName}>
        {Object.entries(node).map(([newKey, value]) => {
          return processNode([...keys, newKey], value, sel)
        })}
      </FormSection>
    )
  }
}
type AttrsOfControlProps = {
  keys: string[]
  description: string | null
  example: Record<string, string | boolean> | null
  defaultValue: Record<string, any> | null
  options: Record<string, any>
  sel: Record<string, any>
}

const AttrsOfControl = (props: AttrsOfControlProps) => {
  const { keys, description, example, defaultValue, options, sel } = props
  const [list, setList] = useState<string[]>(Object.keys(defaultValue || {}))
  if (!example) return <></>
  const name = keys.slice(-1)[0]

  return (
    <FormSection name={name}>
      <FormControl>
        {list.map((item, i) => (
          <FormSection key={i} name={`${item}`}>
            <Flex mb={2} direction="column">
              <FormControl mr={4} mb={4} isRequired>
                <FormLabel>name</FormLabel>
                <Input
                  placeholder="Name"
                  defaultValue={item}
                  onChange={(e) => {
                    setList(list.map((v, j) => (j == i ? e.target.value : v)))
                  }}
                />
              </FormControl>
              {Object.entries(options).map(([key, value]) => (
                processNode([...keys, item, key], value, sel)
              ))}
              <Button as={CloseIcon} onClick={() => setList(list.filter((_, j) => j != i))} />
            </Flex>
          </FormSection>
        ))}
        <Button as={AddIcon} onClick={() => setList([...list, ''])} />
        <FormHelperText style={{ overflowWrap: "anywhere" }}>{description}</FormHelperText>
      </FormControl>
    </FormSection>
  )
}

export const ConfigurationForm = () => {
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const loader: any = useLoaderData();
  const [_, s]: any = useOutletContext();
  const [artifacts, setArtifacts] = useState<Artifact[]>([]);

  let props = {
    schema: s.value,
    nodes: loader.nodes,
  };

  const recursiveReplace = (obj: any) => {
    if ('default' in obj) {
      return obj['default']
    }
    for (const key in obj) {
      obj[key] = recursiveReplace(obj[key])
    }
    return obj
  }

  const handleSubmit = async (e: React.FormEvent<HTMLFormElement>, backendUrl: String) => {
    e.preventDefault()
    setArtifacts([])
    const result = recursiveReplace(structuredClone(props.schema))
    const formData = new FormData(e.target as HTMLFormElement)
    const formDataJson = Object.fromEntries(formData.entries())
    Object.entries(formDataJson).forEach(([key, value]) => {
      // The key should always start with $.schema. or $.nodes.
      if (key.startsWith("$.schema."))
        key = key.replace("schema.", "")
      else
        key = key.replace("nodes.", "")

      const schemaEntry = jp.query(props.schema, key)
      const fieldType = schemaEntry.length > 0 ? schemaEntry[0]['type'] : null
      if (value === '' && fieldType !== 'nullOr') {
        return
      }
      if (fieldType === 'int') {
        jp.apply(result, key, () => parseInt(value as string))
      } else if (fieldType === 'bool') {
        jp.apply(result, key, () => value === '1')
      } else if (fieldType === 'nullOr') {
        jp.apply(result, key, () => (value === '' ? null : value))
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
          parent = jp.query(props.schema, parentPath)
          if (parent.length > 0) {
            parent = parent[0]
            break
          }
        }
        if (parent['type'].startsWith('listOf')) {
          jp.apply(result, parentPath, (v: any) => (Array.isArray(v) ? [...v, value] : [value]));
        } else if (parent['type'].startsWith('attrsOf')) {
          // Parse the JSON path and get the last segment (could be a key or an array index)
          const lastSegment = jp.parse(key).at(-1);

          // Check if the last segment is an array index (e.g., [0], [1])
          const isLastSegmentArrayIndex = lastSegment.expression.type === "numeric_literal";

          // Determine the index of the second-to-last segment in the path
          // If the last segment is an array index, the actual key (array name) is at -3
          // Otherwise, it's just the previous segment at -2
          const secondLastSegmentIndex = isLastSegmentArrayIndex ? -3 : -2;

          // Extract the key from the second-to-last segment
          const parentKey = jp.parse(key).at(secondLastSegmentIndex)['expression']['value'];

          // Construct the object path by combining the parent path and the extracted key
          const fullObjectPath = jp.stringify([
            ...jp.parse(parentPath).map((segment: any) => segment['expression']['value']),
            parentKey
          ]);

          // Query the object at the constructed path
          const targetObject = jp.query(result, fullObjectPath);

          // If the target object doesn't exist, initialize it as an empty object
          if (targetObject.length === 0) {
            jp.apply(result, parentPath, (parentObject: any) => ({ ...parentObject, [parentKey]: {} }));
          }

          // Determine the key to modify within the target object
          // If the last segment is an array index, use the second-to-last segment (array name)
          // Otherwise, use the last segment (regular key)
          const targetKey = isLastSegmentArrayIndex ?
            jp.parse(key).at(-2)['expression']['value']
            : jp.parse(key).at(-1)['expression']['value'];

          // If the target is an array, append the new value
          if (isLastSegmentArrayIndex) {
            jp.apply(result, fullObjectPath, (v: any) => ({
              ...v,
              [targetKey]: Array.isArray(v[targetKey])
                ? [...v[targetKey], value]
                : [value]
            }));
          }
          // If the target key is 'enable', store a boolean value (true if '1', false otherwise)
          else if (targetKey === 'enable') {
            jp.apply(result, fullObjectPath, (v: any) => ({
              ...v,
              [targetKey]: value === '1'
            }));
          }
          // Otherwise, update the object with the new value
          else {
            jp.apply(result, fullObjectPath, (v: any) => ({
              ...v,
              [targetKey]: value
            }));
          }
        }
      } else {
        jp.apply(result, key, () => value)
      }
    })
    setIsLoading(true);
    setError(null);
    try {
      const response = await fetch(`${backendUrl}/nixosConfig`, {
        method: 'POST',
        headers: {
          'Access-Control-Allow-Origin': '*',
          Accept: 'application/json',
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(result),
        mode: 'cors',
      });
      if (!response.ok) {
        throw new Error(`HTTP error! Status: ${response.status}`);
      }
      const responseData = await response.json();
      if (responseData.status === "ok" && responseData.artifacts) {
        // Artifact links are relative so we add the backend url as prefix
        let afrtifacts: Artifact[] = responseData.artifacts;
        afrtifacts.forEach((a) => {
          a.download_url = `${backendUrl}${a.download_url}`;
        });

        setArtifacts(afrtifacts);
      } else {
        setError("Error: No artifacts links found.");
      }

    } catch (error: any) {
      setError(error.message);
    } finally {
      setIsLoading(false);
    }

  }

  const templates = () => {
    const [selectedTemplate, setSelectedTemplate] = useState("0");
    const backend = useBackend()

    const joined = new Array()
    joined.push(props.schema)
    joined.push(...props.nodes)

    const options = [<option key={0} value="0">New node template</option>]
    const extOpt = props.nodes.map((v: any, i: number) => (<option key={i + 1} value={i + (options.length)}>{v.localization.hostname}</option>))
    const jopt = new Array()
    jopt.push(...options)
    jopt.push(...extOpt)

    const chosenJSON: Record<string, any> = joined.at(parseInt(selectedTemplate))

    const root = selectedTemplate == "0" ? "schema" : "nodes"

    return (
      <form onSubmit={e => handleSubmit(e, backend.backendUrl)}>
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
        <Select value={selectedTemplate} onChange={e => setSelectedTemplate(e.target.value)}>
          {jopt}
        </Select>
        {processNode([root], structuredClone(props.schema), chosenJSON)}
        {isLoading && (
          <VStack spacing={2} align="center">
            <Spinner size="xl" />
            <Text fontSize="xl" fontWeight="bold" color="gray.600">
              BUIDL in progress!
            </Text>
          </VStack>
        )}
        <VStack spacing={4} align="stretch" maxWidth="600px" margin="auto" mb={10}>
          {error && (
            <Alert status="error">
              <AlertIcon />
              <AlertTitle>Error!</AlertTitle>
              <AlertDescription>{error}</AlertDescription>
            </Alert>
          )}

          {artifacts.length > 0 && (
            <ArtifactsList artifacts={artifacts} />
          )}
        </VStack>
        <Button w="100%" type="submit">
          #BUIDL
        </Button>

      </form>
    )
  }

  return (
    <>
      {templates()}
    </>
  )
}

export default ConfigurationForm
