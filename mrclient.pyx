cdef extern from "moira/mrclient.h":
    int mrcl_connect(char * server, char * client, int version, int auth)
    char * mrcl_krb_user()
    char * c_partial_canonicalize_hostname "partial_canonicalize_hostname" (char * s)
    char * mrcl_get_message()
    void mrcl_com_err(char * whoami)
    int mrcl_validate_pobox_smtp(char * user, char * address, char ** ret)

    enum:
        MRCL_SUCCESS
        MRCL_FAIL
        MRCL_REJECT
        MRCL_WARN
        MRCL_ENOMEM
        MRCL_MOIRA_ERROR
        MRCL_AUTH_ERROR

cdef extern from "stdlib.h":
    void free(void * ptr)

cdef extern from "string.h":
    char * strdup(char * s)

cdef public char * whoami

class MoiraClientException(Exception):
    def code(self):
        return self.args[0]
    code = property(code)

def _error(code, text=None):
    if code == MRCL_ENOMEM:
        text = "Out of memory"
    if code == MRCL_MOIRA_ERROR:
        text = "Moira Error"
    if code == MRCL_AUTH_ERROR:
        text = "Authentication error"
    if mrcl_get_message():
        if text == None:
            text = mrcl_get_message()
        else:
            text = "%s (%s)" % (text, mrcl_get_message())
    raise MoiraClientException(code, text)

def connect(server='', client='mrclient.py', version=-1, auth=1):
    status = mrcl_connect(server, client, version, auth)
    if status != MRCL_SUCCESS:
       _error(status)
    whoami = client
    
def krb_user():
    cdef char * c_krb_user
    cdef object py_krb_user
    c_krb_user = mrcl_krb_user()
    if c_krb_user == NULL:
       _error(-1, "Could not retrieve principal name")
    py_krb_user = c_krb_user
    free(c_krb_user)
    return py_krb_user

def validate_pobox_smtp(user, address):
    cdef char * c_retval
    cdef object py_retval
    py_retval = address
    status = mrcl_validate_pobox_smtp(user, address, &c_retval)
    if status != MRCL_SUCCESS:
        _error(status)
    if c_retval != NULL:
        py_retval = c_retval
        free(c_retval)
    return py_retval

def partial_canonicalize_hostname(host):
    cdef object py_hostname
    cdef char * c_hostname
    c_hostname = c_partial_canonicalize_hostname(strdup(host))
    py_hostname = c_hostname
    free(c_hostname)
    return py_hostname

