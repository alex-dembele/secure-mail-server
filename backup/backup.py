import os
import boto3
import datetime
import mysql.connector
from mysql.connector import Error
import tarfile
import shutil

S3_BUCKET = os.getenv('S3_BUCKET')
BACKUP_DIR = '/tmp/backup'
TIMESTAMP = datetime.datetime.now().strftime('%Y%m%d_%H%M%S')

def backup_database():
    connection = None
    try:
        connection = mysql.connector.connect(
            host=os.getenv('MYSQL_HOST'),
            user=os.getenv('MYSQL_USER'),
            password=os.getenv('MYSQL_PASSWORD'),
            database=os.getenv('MYSQL_DATABASE')
        )
        os.makedirs(BACKUP_DIR, exist_ok=True)
        backup_file = f"{BACKUP_DIR}/db_backup_{TIMESTAMP}.sql"
        with open(backup_file, 'w') as f:
            cursor = connection.cursor()
            cursor.execute("SHOW TABLES")
            tables = cursor.fetchall()
            for table in tables:
                table_name = table[0]
                cursor.execute(f"SELECT * INTO OUTFILE '/tmp/{table_name}.sql' FROM {table_name}")
                with open(f"/tmp/{table_name}.sql", 'r') as tf:
                    f.write(tf.read())
        return backup_file
    except Error as e:
        print(f"Error backing up database: {e}")
        return None
    finally:
        if connection and connection.is_connected():
            cursor.close()
            connection.close()

def compress_backup(backup_file):
    compressed_file = f"{BACKUP_DIR}/backup_{TIMESTAMP}.tar.gz"
    with tarfile.open(compressed_file, "w:gz") as tar:
        tar.add(backup_file, arcname=os.path.basename(backup_file))
        tar.add('/backup/dbdata', arcname='dbdata')
        tar.add('/backup/maildata', arcname='maildata')
        tar.add('/backup/certs', arcname='certs')
    return compressed_file

def upload_to_s3(file_path):
    s3_client = boto3.client(
        's3',
        aws_access_key_id=os.getenv('AWS_ACCESS_KEY_ID'),
        aws_secret_access_key=os.getenv('AWS_SECRET_ACCESS_KEY'),
        region_name=os.getenv('AWS_DEFAULT_REGION')
    )
    try:
        s3_client.upload_file(file_path, S3_BUCKET, os.path.basename(file_path))
        print(f"Uploaded {file_path} to S3 bucket {S3_BUCKET}")
    except Exception as e:
        print(f"Error uploading to S3: {e}")

def restore_from_s3(s3_key):
    s3_client = boto3.client(
        's3',
        aws_access_key_id=os.getenv('AWS_ACCESS_KEY_ID'),
        aws_secret_access_key=os.getenv('AWS_SECRET_ACCESS_KEY'),
        region_name=os.getenv('AWS_DEFAULT_REGION')
    )
    restore_dir = f"{BACKUP_DIR}/restore_{TIMESTAMP}"
    os.makedirs(restore_dir, exist_ok=True)
    local_file = f"{restore_dir}/{s3_key}"
    try:
        s3_client.download_file(S3_BUCKET, s3_key, local_file)
        with tarfile.open(local_file, "r:gz") as tar:
            tar.extractall(restore_dir)
        print(f"Restored {s3_key} to {restore_dir}"")
        connection = mysql.connector.connect(
            host=os.getenv('MYSQL_HOST'),
            user=os.getenv('MYSQL_USER'),
            password=os.getenv('MYSQL_PASSWORD'),
            database=os.getenv('MYSQL_DATABASE')
        )
        cursor = connection.cursor()
        with open(f"{restore_dir}/db_backup.sql"), 'r') as f:
            sql_statements = f.read().split(';')
            for statement in sql_statements:
                if statement.strip():
                    cursor.execute(statement)
            connection.commit()
        print("Database restored successfully")
    except Exception as e:
        print(f"Error restoring from S3: {e}")
    finally
        if connection and connection.is_connected():
            cursor.close()
            connection.close()

if __name__ == '__main__':
    db_backup = backup_database()
    if db_backup:
        compressed_file = compressed_backup(db_backup)
        upload_to_s3(compressed_file)
        shutil.rmtree(BACKUP_DIR)