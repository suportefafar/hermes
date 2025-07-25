import express from "express";
import cors from "cors";

import emails from "./routes/emails.js";

const app = express();
const port = 3000;

//  origin: "https://www.farmacia.ufmg.br", WORKS
const corsOptions = {
  origin: "*",
  optionsSuccessStatus: 200, // some legacy browsers (IE11, various SmartTVs) choke on 204
};

app.use(cors(corsOptions));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

app.use("/api/v1/emails", emails);

app.get("/", (req, res) => {
  console.log("LOG::: GET HTTP");
  res.json({ error: false, msg: "200" });
});

app.post("/", (req, res) => {
  console.log("LOG::: POST HTTP");
  return res.send(" POST HTTP");
});

app.put("/", (req, res) => {
  console.log("LOG::: PUT HTTP");
  return res.send(" PUT HTTP");
});

app.delete("/", (req, res) => {
  console.log("LOG::: DELETE HTTP");
  return res.send(" DELETE HTTP");
});

app.listen(port, () => {
  console.log(`HERMES running on port ${port}`);
});
