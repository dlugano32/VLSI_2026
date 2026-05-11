Gearbox -> Tiene dos dominios de reloj, dond
Sincronizador -> Pasar de un dominio de reloj lento/rapido a uno rapido/lento.
	Por ejemplo queremos pasar de la parte de control/dsp de 900MHz/1GHz a dominio de frecuencia del cpu que en ASIC suele ser de 200MHz


Flanco positivo

![[Pasted image 20260511110413.png]]

Los registros no se resetean porque sino habria que sincronizar el reset.

Hacer el flanco negativo