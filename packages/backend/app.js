#!/usr/bin/env node
import express from "express";
import apiRouter from "webui/api.js";
import cors from "cors";

const app = express();
app.use(express.json());
app.use(cors());

app.use(express.static("webui/dist"));
app.use("/api", apiRouter);
app.use("/nixosConfigurations", express.static("webui/nixosConfigurations"));

app.listen(8081);
