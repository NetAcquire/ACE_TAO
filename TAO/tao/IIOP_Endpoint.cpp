// This may look like C, but it's really -*- C++ -*-
// $Id$


#include "tao/IIOP_Endpoint.h"
#include "tao/IIOP_Connect.h"
#include "tao/debug.h"

ACE_RCSID(tao, IIOP_Endpoint, "$Id$")

#if !defined (__ACE_INLINE__)
# include "tao/IIOP_Endpoint.i"
#endif /* __ACE_INLINE__ */

TAO_IIOP_Endpoint::TAO_IIOP_Endpoint (const ACE_INET_Addr &addr,
                                      int use_dotted_decimal_addresses)
  : TAO_Endpoint (TAO_TAG_IIOP_PROFILE), 
    host_ (),
    port_ (0),
    object_addr_ (addr),
    hint_ (0),
    next_ (0)
{
  this->set (addr, use_dotted_decimal_addresses);
}

TAO_IIOP_Endpoint::TAO_IIOP_Endpoint (const char *host,
                                      CORBA::UShort port,
                                      const ACE_INET_Addr &addr)
  : TAO_Endpoint (TAO_TAG_IIOP_PROFILE), 
    host_ (),
    port_ (port),
    object_addr_ (addr),
    hint_ (0),
    next_ (0)
{
  if (host != 0)
    this->host_ = host;
}

TAO_IIOP_Endpoint::TAO_IIOP_Endpoint (void)
  : TAO_Endpoint (TAO_TAG_IIOP_PROFILE), 
    host_ (),
    port_ (0),
    object_addr_ (),
    hint_ (0),
    next_ (0)
{
}

TAO_IIOP_Endpoint::TAO_IIOP_Endpoint (const char *host,
                                      CORBA::UShort port,
                                      CORBA::Short priority)
  : TAO_Endpoint (TAO_TAG_IIOP_PROFILE), 
    host_ (),
    port_ (port),
    object_addr_ (),
    hint_ (0),
    next_ (0)
{
  if (host != 0)
    this->host_ = host;

  this->object_addr_.set_type (-1);
  this->priority (priority);
}

TAO_IIOP_Endpoint::~TAO_IIOP_Endpoint (void)
{
}

int
TAO_IIOP_Endpoint::set (const ACE_INET_Addr &addr,
                        int use_dotted_decimal_addresses)
{
  char tmp_host[MAXHOSTNAMELEN + 1];

  if (use_dotted_decimal_addresses
      || addr.get_host_name (tmp_host, sizeof (tmp_host)) != 0)
    {
      const char *tmp = addr.get_host_addr ();
      if (tmp == 0)
        {
          if (TAO_debug_level > 0)
            ACE_DEBUG ((LM_DEBUG,
                        ACE_TEXT ("\n\nTAO (%P|%t) ")
                        ACE_TEXT ("IIOP_Endpoint::set ")
                        ACE_TEXT ("- %p\n\n"),
                        ACE_TEXT ("cannot determine hostname")));
          return -1;
        }
      else
        this->host_ = tmp;
    }
  else
    this->host_ = CORBA::string_dup (tmp_host);

  this->port_ = addr.get_port_number();

  return 0;
}

int
TAO_IIOP_Endpoint::addr_to_string (char *buffer, size_t length)
{
  size_t actual_len =
    ACE_OS::strlen (this->host_.in ()) // chars in host name
    + sizeof (':')                     // delimiter
    + ACE_OS::strlen ("65536")         // max port
    + sizeof ('\0');

  if (length < actual_len)
    return -1;

  ACE_OS::sprintf (buffer, "%s:%d",
                   this->host_.in (), this->port_);

  return 0;
}

const char *
TAO_IIOP_Endpoint::host (const char *h)
{
  this->host_ = h;

  return this->host_.in ();
}

void
TAO_IIOP_Endpoint::reset_hint (void)
{
  if (this->hint_)
    this->hint_->cleanup_hint ((void **) &this->hint_);
}

