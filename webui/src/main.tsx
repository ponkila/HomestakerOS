import React from 'react'
import ReactDOM from 'react-dom/client'
import { ChakraProvider } from '@chakra-ui/react'
import { App, TabsView, Block } from './App.tsx'
import './index.css'
import { createBrowserRouter, RouterProvider, json } from "react-router-dom";
import { FlakeSection } from './Components/Flake.tsx'
import RegisterSSVForm from './Components/RegisterSSVForm.tsx'
import { StatusPage } from './Components/StatusPage.tsx'
import { NodeInfo, NodeInfoProvider, fetchHostnames, fetchNodeBzImageStatus, fetchNodeInitrdStatus, fetchNodeKexecStatus, fetchNodeSSVKey } from './Context/NodeInfoContext.tsx'
import { fetchNodeConfig } from './Context/NodeInfoContext.tsx'
import * as O from 'fp-ts/Option'
import { ConfigurationForm } from './Components/ConfigurationForm.tsx'
import NodeQuery from './Components/NodeQuery.tsx'
import NodeList from './Components/NodeList.tsx'

const fetchNodes = async (flake: string) => {
  const res = await fetchHostnames(flake);
  const nm = await Promise.all(res.map(async (v, _) => await fetchNodeConfig(flake, v)))
  const nr = nm.map((x) => O.toNullable(x)).flatMap(f => f ? [f] : [])
  return nr
}

export type BlockResponse = {
  host: string;
  data: O.Option<Record<string, any>>;
}

const fetchBlocks = async (nodes: any) => {
  const blocks = await Promise.all(nodes.map(async (n: any) => {
    const data = await Block(n.consensus.lighthouse.endpoint)
    const res: BlockResponse = {
      host: n.localization.hostname,
      data: data,
    }
    return res
  }))
  return blocks
}

const router = createBrowserRouter([
  {
    path: "/",
    element: <App />,
    children: [
      {
        index: true,
        element: <FlakeSection />,
      },
      {
        path: "/:owner/:repo",
        element: <TabsView />,
        loader: async ({ params }) => {
          const flake = `https://raw.githubusercontent.com/${params.owner}/${params.repo}/main`
          const req = await fetch(`${flake}/nixosModules/homestakeros/options.json`)
          const res = await req.json();
          return { schema: res, flake: flake }
        },
        children: [
          {
            index: true,
            element: <StatusPage />,
            loader: async ({ params }) => {
              const flake = `https://raw.githubusercontent.com/${params.owner}/${params.repo}/main`
              const nodes = await fetchNodes(flake)
              const blocks = await fetchBlocks(nodes)
              return { nodes: nodes, blocks: blocks }
            },
          },
          {
            path: "/:owner/:repo/nixosConfigurations",
            element: <ConfigurationForm />,
            loader: async ({ params }) => {
              const flake = `https://raw.githubusercontent.com/${params.owner}/${params.repo}/main`
              const nodes = await fetchNodes(flake)
              return json({ nodes: nodes })
            },
          },
          {
            path: "/:owner/:repo/query",
            element: <NodeQuery />,
          },
          {
            path: "/:owner/:repo/visualize",
            element: <NodeInfoProvider><NodeList /></NodeInfoProvider>,
            loader: async ({ params }) => {
              const flake = `https://raw.githubusercontent.com/${params.owner}/${params.repo}/main`
              const hosts = await fetchHostnames(flake)
              let newNodes = hosts.map((hostname: string): NodeInfo => {
                return {
                  hostname,
                  hasInitrd: false,
                  hasBzImage: false,
                  hasKexec: false,
                  ssvKey: O.none,
                  config: O.none,
                }
              })
              for (const node of newNodes) {
                node.hasInitrd = await fetchNodeInitrdStatus(node.hostname)
                node.hasBzImage = await fetchNodeBzImageStatus(node.hostname)
                node.hasKexec = await fetchNodeKexecStatus(node.hostname)
                node.ssvKey = await fetchNodeSSVKey(node.hostname)
                node.config = await fetchNodeConfig(flake, node.hostname)
              }
              return { newNodes: newNodes }
            },
          },
          {
            element: <NodeInfoProvider><RegisterSSVForm /></NodeInfoProvider>,
            path: "/:owner/:repo/ssvform",
            loader: async ({ params }) => {
              const flake = `https://raw.githubusercontent.com/${params.owner}/${params.repo}/main`
              const hosts = await fetchHostnames(flake)
              let newNodes = hosts.map((hostname: string): NodeInfo => {
                return {
                  hostname,
                  hasInitrd: false,
                  hasBzImage: false,
                  hasKexec: false,
                  ssvKey: O.none,
                  config: O.none,
                }
              })
              for (const node of newNodes) {
                node.hasInitrd = await fetchNodeInitrdStatus(node.hostname)
                node.hasBzImage = await fetchNodeBzImageStatus(node.hostname)
                node.hasKexec = await fetchNodeKexecStatus(node.hostname)
                node.ssvKey = await fetchNodeSSVKey(node.hostname)
                node.config = await fetchNodeConfig(flake, node.hostname)
              }
              return { newNodes: newNodes }
            },
          },
        ],
      },
      
    ],
  },
]);

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <ChakraProvider>
      <RouterProvider router={router} />
    </ChakraProvider>
  </React.StrictMode>
)
