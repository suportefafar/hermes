import { prismaClient } from "../database/prisma-client.js";
import { sendEmail } from "../service/email.js";

function create(data) {
  return prismaClient.email.create({
    data,
  });
}

export async function createOne(req, res) {
  const data = req.body;

  console.log(data);

  try {
    const response = await create(data);

    res.status(200).json({ ...response });
  } catch (error) {
    console.log(error);
    res.status(500).json(error);
  }
  disconnect();
}

export async function deleteOne(req, res) {
  const id = req.params.id;
  try {
    const response = await prismaClient.email.delete({ where: { id } });
    res.status(200).json(response);
  } catch (error) {
    res.status(500).json(error);
  }
  disconnect();
}

export async function editOne(req, res) {
  const data = req.body;
  const id = req.params.id;

  try {
    const response = await prismaClient.email.update({
      where: { id },
      data,
    });
    res.status(200).json(response);
  } catch (error) {
    res.status(500).json(error);
  }
  disconnect();
}

export async function getAll(req, res) {
  try {
    const response = await prismaClient.email.findMany();
    res.status(200).json(response);
  } catch (error) {
    res.status(500).json(error);
  }
  disconnect();
}

export async function getOne(req, res) {
  const id = req.params.id;
  try {
    const response = await prismaClient.email.findFirst({ where: { id } });
    res.status(200).json(response);
  } catch (error) {
    res.status(500).json(error);
  }
  disconnect();
}

export async function sendOne(req, res) {
  const data = req.body;

  console.log(data);

  try {
    const response = await sendEmail(data);

    const { had_error } = response;

    if (had_error) res.status(400).json({ ...response });
    else res.status(200).json({ ...response });
  } catch (error) {
    console.log(error);
    res.status(500).json(error);
  }
  disconnect();
}

export async function sendAndSaveOne(req, res) {
  const data = req.body;

  console.log(data);

  try {
    const email_response = await sendEmail(data);

    const { to, from, subject, body_content, had_error } = email_response;

    const db_data = {
      to,
      from,
      subject,
      body_content,
      had_error,
    };
    console.log(db_data);
    const response = await create(db_data);

    if (had_error) res.status(400).json({ ...response });
    else res.status(200).json({ ...response });
  } catch (error) {
    console.log(error);
    res.status(500).json(error);
  }
}

export async function disconnect() {
  await prismaClient.$disconnect();
}
