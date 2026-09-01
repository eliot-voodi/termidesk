# Копирование конфигурации на доп. диспетчеры
sudo scp -r /etc/opt/termidesk-vdi admin@<target>:/home/admin/
ssh admin@<target> 'sudo mv /home/admin/termidesk-vdi /etc/opt/'
# Затем apt install termidesk-vdi с теми же параметрами БД/RabbitMQ
Эталон: disp1.termidesk.local (192.0.2.30)