typedef struct _HINTERNET* HINTERNET;

typedef int INTERNET_SCHEME;
typedef unsigned short INTERNET_PORT;

typedef struct _WINHTTP_URL_COMPONENTS {
	unsigned long StructSize;
	wchar_t* Scheme;
	unsigned long SchemeLength;
	INTERNET_SCHEME nScheme;
	wchar_t* HostName;
	unsigned long HostNameLength;
	INTERNET_PORT nPort;
	wchar_t* UserName;
	unsigned long UserNameLength;
	wchar_t* Password;
	unsigned long PasswordLength;
	wchar_t* UrlPath;
	unsigned long UrlPathLength;
	wchar_t* ExtraInfo;
	unsigned long ExtraInfoLength;
} URL_COMPONENTS;

unsigned long GetLastError();

unsigned long FormatMessageA(
	/*[in]          */ unsigned long Flags,
	/*[in, optional]*/ const void* Source,
	/*[in]          */ unsigned long MessageId,
	/*[in]          */ unsigned long LanguageId,
	/*[out]         */ char*  Buffer,
	/*[in]          */ unsigned long nSize,
	/*[in, optional]*/ va_list *Arguments // va-list????
);

void* LocalFree(
  /*[in]*/ void* hMem
);

bool WinHttpCrackUrl(
	/*[in]     */ const wchar_t* Url,
	/*[in]     */ unsigned long UrlLength,
	/*[in]     */ unsigned long Flags,
	/*[in, out]*/ URL_COMPONENTS* UrlComponents
);

HINTERNET WinHttpOpen(
	/*[in, optional]*/ const wchar_t* AgentW,
	/*[in]          */ unsigned long AccessType,
	/*[in]          */ const wchar_t* ProxyW,
	/*[in]          */ const wchar_t* ProxyBypassW,
	/*[in]          */ unsigned long Flags
);

HINTERNET WinHttpConnect(
	/*[in]*/ HINTERNET hSession,
	/*[in]*/ const wchar_t* pswzServerName,
	/*[in]*/ INTERNET_PORT nServerPort,
	/*[in]*/ unsigned long Reserved
);

HINTERNET WinHttpOpenRequest(
	/*[in]*/ HINTERNET hConnect,
	/*[in]*/ const wchar_t* Verb,
	/*[in]*/ const wchar_t* ObjectName,
	/*[in]*/ const wchar_t* Version,
	/*[in]*/ const wchar_t* Referrer,
	/*[in]*/ const wchar_t* *AcceptTypes,
	/*[in]*/ unsigned long Flags
);

bool WinHttpAddRequestHeaders(
	/*[in]*/ HINTERNET hRequest,
	/*[in]*/ const char* Headers,
	/*[in]*/ unsigned long HeadersLength,
	/*[in]*/ unsigned long Modifiers
);

bool WinHttpSendRequest(
	/*[in]          */ HINTERNET hRequest,
	/*[in, optional]*/ const wchar_t* Headers,
	/*[in]          */ unsigned long HeadersLength,
	/*[in, optional]*/ void* Optional,
	/*[in]          */ unsigned long OptionalLength,
	/*[in]          */ unsigned long TotalLength,
	/*[in]          */ void* Context
);

bool WinHttpReceiveResponse(
	/*[in]*/ HINTERNET hRequest,
	/*[in]*/ void*    Reserved
);

bool WinHttpQueryDataAvailable(
	/*[in] */ HINTERNET hRequest,
	/*[out]*/ unsigned long* NumberOfBytesAvailable
);

bool WinHttpReadData(
	/*[in] */ HINTERNET hRequest,
	/*[out]*/ void* Buffer,
	/*[in] */ unsigned long NumberOfBytesToRead,
	/*[out]*/ unsigned long* NumberOfBytesRead
);

bool WinHttpCloseHandle(
	/*[in]*/ HINTERNET hInternet
);

bool WinHttpQueryHeaders(
	/*[in]          */ HINTERNET hRequest,
	/*[in]          */ unsigned long InfoLevel,
	/*[in, optional]*/ const wchar_t* Name,
	/*[out]         */ void* Buffer,
	/*[in, out]     */ unsigned long* BufferLength,
	/*[in, out]     */ unsigned long* Index
);

size_t mbstowcs(wchar_t* wcstr, const char* mbstr, size_t len);
size_t wcstombs(char* mbstr, const wchar_t* wcstr, size_t len);