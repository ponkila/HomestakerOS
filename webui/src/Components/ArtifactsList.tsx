import { Box, Heading, VStack, Link, Text, Code, HStack, IconButton, useClipboard } from "@chakra-ui/react";
import { CopyIcon } from "@chakra-ui/icons";

export interface Artifact {
  download_url: string;
  file: string;
  sha256: string;
}

const ArtifactsList = ({ artifacts }: { artifacts: Artifact[] }) => {
  
  return (
    <Box>
      <Heading as="h3" size="md" mb={2}>
        Artifacts:
      </Heading>
      <VStack spacing={3} align="start" width="full">
        {artifacts.map((artifact, index) => (
          <ArtifactItem key={index} artifact={artifact} />
        ))}
      </VStack>
    </Box>
  );
};

const ArtifactItem = ({ artifact }: { artifact: Artifact }) => {
  const { onCopy, hasCopied } = useClipboard(artifact.sha256);

  return (
    <Box p={3} borderWidth={1} borderRadius="md" width="full">
      <Link href={artifact.download_url} download isExternal fontWeight="bold" color="blue.500">
        {artifact.file}
      </Link>
      <HStack mt={3} spacing={2} align="center" justify="space-between">
        <Text fontWeight="semibold">SHA256:</Text>
        <Code fontSize="sm" p={2} borderRadius="md" whiteSpace="nowrap" overflow="hidden" textOverflow="ellipsis">
        {artifact.sha256}
        </Code>
        <IconButton
          aria-label="Copy SHA256"
          icon={<CopyIcon />}
          size="sm"
          onClick={onCopy}
        />
        {hasCopied && <Text fontSize="sm" color="green.500">Copied!</Text>}
      </HStack>
    </Box>
  );
};

export default ArtifactsList;