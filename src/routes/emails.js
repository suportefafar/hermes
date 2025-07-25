import express, { Router } from "express";

import {
  createOne,
  deleteOne,
  editOne,
  getAll,
  getOne,
  sendOne,
  sendAndSaveOne,
} from "../controllers/emails.js";

const routes = express.Router();

routes.route("/").get(getAll);

routes.route("/send").post(sendOne);
routes.route("/sendAndSave").post(sendAndSaveOne);

routes.route("/:id").get(getOne);

export default routes;
