import nodemailer from "nodemailer";

function getPreHTML(msg) {
  return `
  <!DOCTYPE html>
  <html lang='pt-BR'>
  <head>
    <meta charset='UTF-8'>
    <meta http-equiv='X-UA-Compatible' content='IE=edge'>
    <meta name='viewport' content='width=device-width, initial-scale=1.0'>
    <title>Faculdade de Farmácia - UFMG</title>
  </head>
  <body style='margin: 0; padding: 0'>
    <table
      align='center'
      cellpadding='0'
      cellspacing='0'
      width='600'
      style='border-collapse: collapse; width: 600px'
      bgcolor='#e4e4e4'
    >
      <tr></tr>
      <tr>
        <td
          bgcolor='#f2b600'
          height='100'
          style='padding-left: 139px; padding-top: 3px'
        >
          <img
            src='https://www.farmacia.ufmg.br//wp-content/uploads/2015/01/logo-Ufmg.png'
          />
        </td>
      </tr>
      <tr>
        <td
          height='100'
          style='
            padding-top: 8px;
            padding-bottom: 8px;
            padding-left: 16px;
            padding-right: 16px;
          '
        >
          <h3 align='left'>Prezado(a),</h3>
          <h4 align='center'>${msg}</h4>
        </td>
      </tr>
      <tr>
        <td
          bgcolor='#404040'
          height='100'
          style='
            padding-top: 8px;
            padding-bottom: 8px;
            padding-left: 16px;
            padding-right: 16px;
          '
        >
          <h6
            align='center'
            style='margin-top: 0; margin-bottom: 0; color: #fff'
          >
            Esta é uma mensagem gerada automaticamente. Para mais informações
            entre contato via telefone: (31) 3409-6751
            <br />
            <br />
            Av. Presidente Antônio Carlos, 6627 - Campus Pampulha - CEP
            31270-901<br />Belo Horizonte - MG - Brasil
            <br />
            <br />
            <a href='https://www.ufmg.br' target='_blank'
              ><img
                width='64'
                src='https://www.farmacia.ufmg.br/wp-content/uploads/2015/01/logo-rodape2.png'
            /></a>
          </h6>
        </td>
      </tr>
    </table>
  </body>
</html>
  `;
}

export async function sendEmail(data) {
  console.log(process.env);
  const {
    user = process.env.SUPORTE_ACCOUNT,
    pass = process.env.SUPORTE_PASS,
    from = user,
    to = "suporte@farmacia.ufmg.br",
    subject = "SEM ASSUNTO",
    text = "SEM CORPO DO EMAIL",
  } = data;

  console.log("CAME THIS:", data);

  let body_content = "";
  let html = "";
  if (data.content_in_pre_html) {
    html = getPreHTML(data.content_in_pre_html);
    body_content = data.content_in_pre_html;
  } else if (data.html) body_content = html = data.html;
  else if (data.text) body_content = html = data.text;

  console.log("SEND EMAIL");
  console.log({
    ...data,
    body_content,
    user,
    pass,
    from,
    to,
    subject,
    text,
  });
  console.log("HERMES_SUPORTE_PASS: ", process.env.HERMES_SUPORTE_PASS);

  let transporter = nodemailer.createTransport({
    host: "smtp.grude.ufmg.br",
    port: 465,
    secure: true,
    auth: {
      user,
      pass,
    },
  });
  const return_obj = {
    to,
    from,
    subject,
    body_content,
    had_error: false,
  };
  try {
    await transporter.sendMail({
      from,
      to,
      subject,
      text,
      html,
    });

    return { ...return_obj, error: {} };
  } catch (error) {
    console.log(error);
    return { ...return_obj, had_error: true, error };
  }
}
