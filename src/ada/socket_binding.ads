with Interfaces.C; use Interfaces.C;
-- with Compiler_Port; use Compiler_Port;
with Tcp_Type; use Tcp_Type;
with Error_H; use Error_H;
with System;
with Ip; use Ip;
with Common_type; use Common_type;
with Socket_Type; use Socket_Type;

package Socket_Binding is

   function getHostByName(Net_Interface : System.Address; Server_Name : char_array; Serveur_Ip_Addr: out IpAddr; Flags : unsigned)
   return unsigned
     with
      Import => True,
      Convention => C,
      External_Name => "getHostByName";

   -- function socketOpen (S_Type: Sock_Type; protocol: Sock_Protocol) return Socket 
   -- with
   --     Import => True,
   --     Convention => C,
   --     External_Name => "socketOpen";

   -- function socketSetTimeout (sock: Socket; timeout: Systime) return unsigned
   --  with
   --    Import => True,
   --    Convention => C,
   --    External_Name => "socketSetTimeout";

   -- function socketSetTtl(sock: Socket; ttl: unsigned_char) return unsigned
   --  with
   --    Import => True,
   --    Convention => C,
   --    External_Name => "socketSetTtl";

   -- function socketSetMulticastTtl(sock: Socket; ttl: unsigned_char) return unsigned
   --  with
   --    Import => True,
   --    Convention => C,
   --    External_Name => "socketSetMulticastTtl";
   
   -- function socketConnect (sock: Socket; remoteIpAddr: IpAddr; remotePort: Port)
   -- return unsigned
   -- with
   --    Import => True,
   --    Convention => C,
   --    External_Name => "socketConnect";

   function socketSend (sock: Socket; data: char_array; length: unsigned; written: out unsigned; flags: unsigned)
   return unsigned
   with
      Import => True,
      Convention => C,
      External_Name => "socketSend";

   function socketReceive(sock: Socket; data: out char_array; size: unsigned; received: out unsigned; flags: unsigned)
   return unsigned
   with
      Import => True,
      Convention => C,
      External_Name => "socketReceive";

   -- function socketShutdown (sock: Socket; how: unsigned)
   -- return unsigned
   -- with
   --    Import => True,
   --    Convention => C,
   --    External_Name => "socketShutdown";

   procedure socketClose (sock: Socket)
   with
      Import => True,
      Convention => C,
      External_Name => "socketClose";

   -- function socketSetTxBufferSize (sock: Socket; size: unsigned_long)
   -- return unsigned
   -- with
   --    Import => True,
   --    Convention => C,
   --    External_Name => "socketSetTxBufferSize";

   -- function socketSetRxBufferSize (sock: Socket; size: unsigned_long)
   -- return unsigned
   -- with
   --    Import => True,
   --    Convention => C,
   --    External_Name => "socketSetRxBufferSize";

   -- function socketBind (sock: Socket; localIpAddr: System.Address; localPort: Port)
   -- return unsigned
   -- with
   --    Import => True,
   --    Convention => C,
   --    External_Name => "socketBind";

   -- function socketListen (sock: Socket; backlog: unsigned)
   -- return unsigned
   -- with
   --    Import => True,
   --    Convention => C,
   --    External_Name => "socketListen";

   -- function socketAccept (sock: Socket; clientIpAddr: out IpAddr; clientPort: out Port)
   -- return Socket
   -- with
   --    Import => True,
   --    Convention => C,
   --    External_Name => "socketAccept";

   
end Socket_Binding;
