CREATE DATABASE client;
GRANT ALL PRIVILEGES ON *.* TO 'db_user'@'%' WITH GRANT OPTION;
CREATE TABLE client.client_info (
	id INT primary key auto_increment NOT NULL,
	ip varchar(100) NOT NULL,
	qr_code varchar(100) NOT NULL,
	created_at DATETIME NOT NULL
)