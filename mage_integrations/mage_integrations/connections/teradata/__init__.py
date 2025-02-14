from mage_integrations.connections.sql.base import Connection
import enum
from sshtunnel import SSHTunnelForwarder
import io
import os
import paramiko
import teradatasql


class ConnectionMethod(str, enum.Enum):

    DIRECT = 'direct'

    SSH_TUNNEL = 'ssh_tunnel'

class Teradata(Connection):

    def __init__(self, database: str, host: str, password: str, username: str, port: int = None, connection_method: ConnectionMethod = ConnectionMethod.DIRECT, ssh_host: str = None,
                 ssh_port: int = 22, ssh_username: str = None, ssh_password: str = None, ssh_pkey: str = None, **kwargs):

        super().__init__(**kwargs)

        self.connection_method = connection_method

        self.database = database

        self.host = host

        self.password = password

        self.port = 1025 # Modify the default Teradata port as needed

        self.username = username

        self.ssh_host = ssh_host

        self.ssh_port = ssh_port

        self.ssh_username = ssh_username

        self.ssh_password = ssh_password

        self.ssh_pkey = ssh_pkey

        self.ssh_tunnel = None

    def build_connection(self):

        host = self.host

        port = self.port

        if self.connection_method == ConnectionMethod.SSH_TUNNEL:

            ssh_setting = dict(ssh_username=self.ssh_username)

            if self.ssh_pkey is not None:

                if os.path.exists(self.ssh_pkey):

                    ssh_setting['ssh_pkey'] = self.ssh_pkey

                else:

                    ssh_setting['ssh_pkey'] = paramiko.RSAKey.from_private_key(io.StringIO(self.ssh_pkey))

            else:

                ssh_setting['ssh_password'] = self.ssh_password

            self.ssh_tunnel = SSHTunnelForwarder((self.ssh_host, self.ssh_port), remote_bind_address=(self.host, self.port),
                                                 local_bind_address=('', self.port), **ssh_setting)

            self.ssh_tunnel.start()

            self.ssh_tunnel._check_is_started()

            host = '127.0.0.1'

           # port = self.ssh_tunnel.local_bind_port

        return teradatasql.connect(host=host, user=self.username, password=self.password, database=self.database, dbs_port = 1025 )
"""
    def close_connection(self, Connection):

        Connection.close_connection(self, Teradata)

        if self.ssh_tunnel is not None:

            self.ssh_tunnel.stop()

            self.ssh_tunnel = None
"""
