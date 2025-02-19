import React, { createContext, useState, useContext, ReactNode, useEffect } from "react";

interface BackendContextType {
  backendUrl: string;
  setBackendUrl: (url: string) => void;
}

const BackendContext = createContext<BackendContextType | undefined>(undefined);

export const BackendProvider: React.FC<{ children: ReactNode }> = ({ children }) => {
  
  const getUrlFromHash = (): string => {
    const hash = window.location.hash;
    const params = new URLSearchParams(hash.slice(1));
    return params.get("backendUrl") || "http://localhost:8081";
  };

  const [backendUrl, setBackendUrl] = useState<string>(getUrlFromHash);

  useEffect(() => {
    // Updates the url if user changes backendurl manually
    const handleHashChange = () => {
      const newBackendUrl = getUrlFromHash();
      setBackendUrl(newBackendUrl);
    };

    window.addEventListener("hashchange", handleHashChange);

    return () => {
      window.removeEventListener("hashchange", handleHashChange);
    };
  }, []);

  useEffect(() => {
    // Updates the URL when it's changed from main page
    window.location.hash = `backendUrl=${backendUrl}`;
  }, [backendUrl]);

  return (
    <BackendContext.Provider value={{ backendUrl, setBackendUrl }}>
      {children}
    </BackendContext.Provider>
  );
};

export const useBackend = (): BackendContextType => {
  const context = useContext(BackendContext);
  if (!context) {
    throw new Error("useBackend must be used within a BackendProvider");
  }
  return context;
};
