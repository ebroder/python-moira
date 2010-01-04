cdef extern from "moira/moira.h":
    int mr_krb5_auth(char * prog)
    int mr_auth(char * prog)
    int mr_connect(char * server)
    int mr_disconnect()
    int mr_host(char * host_buf, int buf_size)
    int mr_motd(char ** motd)
    int mr_noop()
    int mr_query(char * handle, int argc, char ** argv,
                 int (*callback)(int, char **, void *), object callarg)
    int mr_access(char *handle, int argc, char ** argv)
    int mr_proxy(char *principal, char *orig_authtype)

    enum:
        MR_SUCCESS
        MR_CONT

cdef extern from "com_err.h":
    ctypedef long errcode_t
    char * error_message(errcode_t)

cdef extern from "stdlib.h":
    ctypedef unsigned long size_t
    void * malloc(size_t size)
    void free(void * ptr)

class MoiraException(Exception):
    def code(self):
        return self.args[0]
    code = property(code)

__connected = False

def _error(code):
    raise MoiraException, (code, error_message(code))

def connect(server=''):
    """
    Establish a connection to a Moira server.
    
    A server may be specified, but it is optional. If specified, it
    should be of the form hostname:portname. Portname will be looked
    up in /etc/services if specified, but it is optional as well.
    
    If no server is specified, the server will be found from the
    MOIRASERVER environment variable, Hesiod, or a compiled in default
    (in that order).
    
    This function raises a MoiraException if the connection is
    not successful.
    """
    global __connected
    
    if __connected:
        disconnect()
    
    status = mr_connect(server)
    if status != MR_SUCCESS:
        _error(status)
    else:
        __connected = True

def disconnect():
    """
    Disconnect from the active Moira server
    """
    global __connected
    if __connected:
        mr_disconnect()
    __connected = False

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
    if status != MR_SUCCESS:
        _error(status)

def host():
    """
    Return the name of the host the client is connected to.
    """
    cdef char buffer[512]
    status = mr_host(buffer, 512)
    if status != MR_SUCCESS:
        _error(status)
    return buffer

def motd():
    """
    Retrieve the current message of the day from the server.
    """
    cdef char * motd
    status = mr_motd(&motd)
    if status != MR_SUCCESS:
        _error(status)
    if motd != NULL:
        return motd

def noop():
    """
    Does "no operation" to the server, just making sure it's still
    there
    """
    status = mr_noop()
    if status:
        _error(status)

def _access(handle, *args):
    """
    Verifies that the authenticated user has the access to perform the
    given query.
    """
    cdef int argc, i
    argc = len(args)
    cdef char ** argv
    argv = <char **>malloc(argc * sizeof(char *))

    if argv != NULL:
        for 0 <= i < argc:
            argv[i] = args[i]

        status = mr_access(handle, argc, argv)
        free(argv)

        if status:
            _error(status)

def _query(handle, callback, *args):
    cdef int argc, i
    argc = len(args)
    cdef char ** argv
    argv = <char **>malloc(argc * sizeof(char *))
    
    if argv != NULL:
        for 0 <= i < argc:
            argv[i] = args[i]
        
        status = mr_query(handle, argc, argv, _call_python_callback, callback)
        free(argv)
        
        if status:
            _error(status)

def proxy(principal, orig_authtype):
    """
    Authenticate as a proxy for another principal.

    For those with sufficient privilege, proxy allows an authenticated
    user to impersonate another.

    The principal argument contains the Kerberos principal for which
    this user is proxying, and orig_authtype is the mechanism by which
    the proxied user originally authenticated to the proxier.
    """
    status = mr_proxy(principal, orig_authtype)
    if status != MR_SUCCESS:
        _error(status)

cdef int _call_python_callback(int argc, char ** argv, void * hint):
    cdef object callback
    callback = <object>hint
    result = []
    cdef int i
    for 0 <= i < argc:
        result.append(argv[i])
    callback(tuple(result))
    return MR_CONT
