import React, { createContext, useState, useContext, ReactNode, useEffect } from "react";

interface BackendContextType {
  backendUrl: string;
  setBackendUrl: (url: string) => void;
}

const BackendContext = createContext<BackendContextType | undefined>(undefined);

export const BackendProvider: React.FC<{ children: ReactNode }> = ({ children }) => {
  const savedUrl = localStorage.getItem("backendUrl") || "http://localhost:8081";

  const [backendUrl, setBackendUrl] = useState<string>(savedUrl);

  useEffect(() => {
    localStorage.setItem("backendUrl", backendUrl);
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

