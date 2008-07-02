cdef extern from "moira.h":
    int mr_krb5_auth(char * prog)
    int mr_auth(char * prog)
    int mr_connect(char * server)
    int mr_disconnect()
    int mr_host(char * host_buf, int buf_size)
    int mr_motd(char ** motd)
    int mr_noop()
    int mr_query(char * handle, int argc, char ** argv,
                 int (*callback)(int, char **, void *), void * callarg)
    int mr_version(int version)

class ConnectionException(Exception):
    pass

class AuthenticationException(Exception):
    pass

connected = False

def connect(server=''):
    """
    Establish a connection to a Moira server.
    
    A server may be specified, but it is optional. If specified, it
    should be of the form hostname:portname. Portname will be looked
    up in /etc/services if specified, but it is optional as well.
    
    If no server is specified, the server will be found from the
    MOIRASERVER environment variable, Hesiod, or a compiled in default
    (in that order).
    
    This function raises a ConnectionException if the connection is
    not successful.
    """
    global connected
    
    if connected:
        disconnect()
    
    status = mr_connect(server)
    if status != 0:
        raise ConnectionException, status
    else:
        connected = True

def disconnect():
    """
    Disconnect from the active Moira server
    """
    global connected
    if connected:
        mr_disconnect()
    connected = False

def auth(program, krb4=False):
    """
    Authenticate to the Moira server with Kerberos tickets. If krb4 is
    True, then Kerberos version 4 will be used. Otherwise, Kerberos
    version 5 is used.
    
    The program argument identifies the connecting program to the
    Moira server. This is used for setting the modwith field when
    modifications are made.
    
    Note that the use of Kerberos version 4 is deprecated and highly
    discouraged
    """
    if krb4:
        status = mr_auth(program)
    else:
        status = mr_krb5_auth(program)
    if status != 0:
        raise AuthenticationException, status
