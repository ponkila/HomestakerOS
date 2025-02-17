import { useRouteError, isRouteErrorResponse } from "react-router-dom";
import { Box, Button, Flex, Text } from "@chakra-ui/react";

const ErrorBoundary: React.FC = () => {
  const error = useRouteError();

  return (
    <Flex 
      height="100vh"
      align="center" 
      justify="center" 
      p={4}
    >
      <Box 
        bg="white" 
        p={8} 
        rounded="md" 
        shadow="md" 
        textAlign="center"
      >
        <Text fontSize="2xl" fontWeight="bold" color="red.500">
          ⚠️ Oops! Something went wrong.
        </Text>
        
        {isRouteErrorResponse(error) ? (
          <Text mt={2} fontSize="lg">
            {error.status} - {error.statusText}
          </Text>
        ) : (
          <Text mt={2} fontSize="lg">
            {(error as Error)?.message || "An unexpected error occurred."}
          </Text>
        )}

        <Button 
          as="a" 
          href="/" 
          mt={4} 
          size="lg"
        >
          Go back home
        </Button>
      </Box>
    </Flex>
  );
};

export default ErrorBoundary;

