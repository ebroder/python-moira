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

class Connection(object):
    def __init__(self, server='', auth=None):
        status = mr_connect(server)
        if status != 0:
            raise ConnectionException, status
        if auth is not None:
            status = mr_krb5_auth(auth)
            if status != 0:
                raise AuthenticationException, status
    
    def __del__(self):
        mr_disconnect()
