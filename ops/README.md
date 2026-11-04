# Servidor de CestaLista (Oracle Cloud, Always Free)

- Nombre: `cestalista-servidor` — Madrid (eu-madrid-1), AD-1
- Tamaño: VM.Standard.A1.Flex, 4 OCPU / 24 GB (máximo gratuito), Ubuntu 24.04 (ARM)
- IP pública: 51.170.36.221 (efímera: se mantiene al reiniciar, se pierde si se borra el servidor)
- Usuario: `ubuntu`
- Llave SSH: SOLO en la Cloud Shell de Oracle de Cristina, en `~/.ssh/cestalista` (RSA 4096).
  Entrar desde la Cloud Shell: `ssh -i ~/.ssh/cestalista ubuntu@$(cat ~/.cestalista-ip)`
- El servidor viejo `cestalista-server` (llave "cestalista-deploy", perdida) se borró el 04/11/2026.
- El robot que pedía el servidor está apagado (solo se lanza a mano).
- Alarma de gasto en Oracle: presupuesto "alarma-gasto" de 1 al mes, aviso al 1 % a cestalista5@gmail.com.
