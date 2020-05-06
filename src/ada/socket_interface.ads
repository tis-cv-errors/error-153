pragma Restrictions (No_Tasking);

with Interfaces.C; use Interfaces.C;
with Ip;           use Ip;
with Error_H;      use Error_H;
with Common_Type;  use Common_Type;
with Socket_Types; use Socket_Types;
with Net;          use Net;
with Tcp_binding, Udp_Binding;
use Tcp_binding, Udp_Binding;

package Socket_Interface with
   SPARK_Mode
is
   pragma Unevaluated_Use_Of_Old (Allow);

   Socket_error : exception;

   type Buffer_Size is new Positive;
   type Ttl_Type is mod 2**8;

   type Socket_Protocol is
     (SOCKET_IP_PROTO_ICMP,
      SOCKET_IP_PROTO_IGMP,
      SOCKET_IP_PROTO_TCP,
      SOCKET_IP_PROTO_UDP,
      SOCKET_IP_PROTO_ICMPV6);

   for Socket_Protocol use
     (SOCKET_IP_PROTO_ICMP   => 1,
      SOCKET_IP_PROTO_IGMP   => 2,
      SOCKET_IP_PROTO_TCP    => 6,
      SOCKET_IP_PROTO_UDP    => 17,
      SOCKET_IP_PROTO_ICMPV6 => 58);

   type Host_Resolver is
     (HOST_NAME_RESOLVER_ANY,
      HOST_NAME_RESOLVER_DNS,
      HOST_NAME_RESOLVER_MDNS,
      HOST_NAME_RESOLVER_NBNS,
      HOST_NAME_RESOLVER_LLMNR,
      HOST_TYPE_IPV4,
      HOST_TYPE_IPV6);

   for Host_Resolver use
     (HOST_NAME_RESOLVER_ANY   => 0,
      HOST_NAME_RESOLVER_DNS   => 1,
      HOST_NAME_RESOLVER_MDNS  => 2,
      HOST_NAME_RESOLVER_NBNS  => 4,
      HOST_NAME_RESOLVER_LLMNR => 8,
      HOST_TYPE_IPV4           => 16,
      HOST_TYPE_IPV6           => 32);

   type Socket_Shutdown_Flags is
     (SOCKET_SD_RECEIVE,
      SOCKET_SD_SEND,
      SOCKET_SD_BOTH);

   for Socket_Shutdown_Flags use
     (SOCKET_SD_RECEIVE => 0,
      SOCKET_SD_SEND    => 1,
      SOCKET_SD_BOTH    => 2);

   type Host_Resolver_Flags is array (Positive range <>) of Host_Resolver;

   procedure Get_Host_By_Name
     (Server_Name    :     char_array;
      Server_Ip_Addr : out IpAddr;
      Flags          :     Host_Resolver_Flags;
      Error          : out Error_T)
      with
        Depends =>
          (Server_Ip_Addr => (Server_Name, Flags),
           Error          => (Server_Name, Flags)),
        Post =>
          (if Error = NO_ERROR then Server_Ip_Addr.length > 0);

   procedure Socket_Open
     (Sock       : out Socket;
      S_Type     :     Socket_Type;
      S_Protocol :     Socket_Protocol)
      with
         Global => 
           (Input  => (Net_Mutex, Socket_Table),
            In_Out => Tcp_Dynamic_Port),
         Depends => 
           (Sock             => (S_Type, S_Protocol, Tcp_Dynamic_Port, Socket_Table),
            Tcp_Dynamic_Port => (S_Type, Tcp_Dynamic_Port),
            null             => Net_Mutex),
         Post =>
           (if Sock /= null then
              Sock.S_Descriptor >= 0 and then
              Sock.S_Type = Socket_Type'Enum_Rep (S_Type) and then
              (if S_Type = SOCKET_TYPE_STREAM then
                 Sock.S_Protocol = SOCKET_IP_PROTO_TCP'Enum_Rep
               elsif S_Type = SOCKET_TYPE_DGRAM then
                 Sock.S_Protocol = SOCKET_IP_PROTO_UDP'Enum_Rep
               else
                 Sock.S_Protocol = Socket_Protocol'Enum_Rep (S_Protocol))
              and then 
              Sock.S_remoteIpAddr.length = 0 and then 
              Sock.S_localIpAddr.length = 0 and then
              Sock.S_remoteIpAddr.length = 0);

   procedure Socket_Set_Timeout
      (Sock    : in out Socket;
       Timeout :        Systime)
      with
        Global => 
          (Input => Net_Mutex),
        Depends => 
          (Sock => (Timeout, Sock),
           null => Net_Mutex),
        Pre => 
          Sock /= null,
        Post => 
          Sock /= null and then
          Sock.all = Sock.all'Old'Update (
             S_Timeout => timeout);

   procedure Socket_Set_Ttl
      (Sock : in out Socket;
       Ttl  :        Ttl_Type)
      with
        Global =>
          (Input => Net_Mutex),
        Depends =>
          (Sock => (Ttl, Sock),
           null => Net_Mutex),
        Pre =>
          Sock /= null,
        Post =>
          Sock /= null and then
          Sock.all = Sock.all'Old'Update (
             S_TTL => unsigned_char (Ttl));

   procedure Socket_Set_Multicast_Ttl
      (Sock : in out Socket;
       Ttl  :        Ttl_Type)
      with
        Global =>
          (Input => Net_Mutex),
        Depends =>
          (Sock => (Ttl, Sock),
           null => Net_Mutex),
        Pre =>
          Sock /= null,
        Post =>
          Sock /= null and then 
          Sock.all = Sock.all'Old'Update (
              S_Multicast_TTL => unsigned_char (Ttl));

   procedure Socket_Connect
      (Sock           : in out Socket;
       Remote_Ip_Addr : in     IpAddr;
       Remote_Port    : in     Port;
       Error          :    out Error_T)
      with
        Global => 
          (Input => Net_Mutex),
        Depends => 
          (Sock  => (Sock, Remote_Ip_Addr, Remote_Port),
           Error => (Sock, Remote_Ip_Addr, Remote_Port),
           null  => Net_Mutex),
        Pre => 
          Sock /= null and then
          Remote_Ip_Addr.length > 0,
        Post => 
          Sock /= null and then
          (if Sock.S_Type = Socket_Type'Enum_Rep (SOCKET_TYPE_STREAM) then
             (if Error = NO_ERROR then
                Sock.all = Sock.all'Old'Update
                   (S_remoteIpAddr => Remote_Ip_Addr,
                    S_Remote_Port  => Remote_Port)
             else
                Sock.all = Sock.all'Old)
          elsif Sock.S_Type = Socket_Type'Enum_Rep (SOCKET_TYPE_DGRAM) then
             Error = NO_ERROR and then 
             Sock.all = Sock.all'Old'Update
                   (S_remoteIpAddr => Remote_Ip_Addr,
                    S_Remote_Port  => Remote_Port)
          elsif Sock.S_Type = Socket_Type'Enum_Rep (SOCKET_TYPE_RAW_IP) then
             Error = NO_ERROR and then
             Sock.all = Sock.all'Old'Update 
                (S_remoteIpAddr => Remote_Ip_Addr)
          else
             Sock.all = Sock.all'Old);

   procedure Socket_Send_To
      (Sock         : in out Socket;
       Dest_Ip_Addr :        IpAddr;
       Dest_Port    :        Port;
       Data         : in     char_array;
       Written      :    out Integer;
       Flags        :        unsigned;
       Error        :    out Error_T)
      with
        Global =>
          (Input => Net_Mutex),
        Depends =>
          (Error   => (Sock, Data, Flags),
           Sock    => (Sock, Flags),
           Written => (Sock, Data, Flags),
           null    => (Net_Mutex, Dest_Port, Dest_Ip_Addr)),
        Pre  => 
          Sock /= null and then
          Sock.S_remoteIpAddr.length > 0,
        Post => 
          Sock /= null and then
          (if Error = NO_ERROR then Sock.all = Sock.all'Old);

   procedure Socket_Send
      (Sock    : in out Socket;
       Data    : in     char_array;
       Written :    out Integer;
       Error   :    out Error_T)
      with
        Global =>
          (Input => Net_Mutex),
        Depends =>
          (Error   => (Sock, Data),
           Sock    => Sock,
           Written => (Sock, Data),
           null    => Net_Mutex),
        Pre  =>
          Sock /= null and then
          Sock.S_remoteIpAddr.length > 0,
        Post =>
          Sock /= null and then
          (if Error = NO_ERROR then Sock.all = Sock.all'Old);

   procedure Socket_Receive_Ex
      (Sock         : in out Socket;
       Src_Ip_Addr  :    out IpAddr;
       Src_Port     :    out Port;
       Dest_Ip_Addr :    out IpAddr;
       Data         :    out char_array;
       Received     :    out unsigned;
       Flags        :        unsigned;
       Error        :    out Error_T)
      with
        Global =>
          (Input => Net_Mutex),
        Depends =>
          (Sock         =>  (Sock, Flags),
           Data         =>+ (Sock, Flags),
           Received     =>  (Sock, Flags),
           Src_Ip_Addr  =>  (Sock, Flags),
           Src_Port     =>  (Sock, Flags),
           Dest_Ip_Addr =>  (Sock, Flags),
           Error        =>  (Sock, Flags),
           null         =>  Net_Mutex),
        Pre =>
          Sock /= null and then
          Sock.S_remoteIpAddr.length > 0 and then
          Data'Last >= Data'First,
        Post => 
          Sock /= null and then
          (if Sock.S_Type = SOCKET_TYPE_STREAM'Enum_Rep then
             (if Error = NO_ERROR then
                Sock.all = Sock.all'Old and then
                Received > 0
             elsif Error = ERROR_END_OF_STREAM then
                Sock.all = Sock.all'Old and then
                Received = 0)
          elsif Sock.S_Type /= SOCKET_TYPE_STREAM'Enum_Rep then
             Error = ERROR_INVALID_SOCKET and then
             Sock.all = Sock.all'Old and then
             Received = 0);

   procedure Socket_Receive
      (Sock     : in out Socket;
       Data     :    out char_array;
       Received :    out unsigned;
       Error    :    out Error_T)
      with
        Global =>
          (Input => Net_Mutex),
        Depends =>
          (Sock     =>  Sock,
           Data     =>+ Sock,
           Error    =>  Sock,
           Received =>  Sock,
           null     =>  Net_Mutex),
        Pre =>
          Sock /= null and then
          Sock.S_remoteIpAddr.length > 0 and then
          Data'Last >= Data'First,
        Post => 
          Sock /= null and then
          (if Sock.S_Type = SOCKET_TYPE_STREAM'Enum_Rep then
             (if Error = NO_ERROR then
                Sock.all = Sock.all'Old and then
                Received > 0
             elsif Error = ERROR_END_OF_STREAM then
                Sock.all = Sock.all'Old and then
                Received = 0)
          elsif Sock.S_Type /= SOCKET_TYPE_STREAM'Enum_Rep then
             Error = ERROR_INVALID_SOCKET and then
             Sock.all = Sock.all'Old and then
             Received = 0);

   procedure Socket_Shutdown
      (Sock  : in out Socket;
       How   :        Socket_Shutdown_Flags;
       Error :    out Error_T)
      with
        Global =>
          (Input => Net_Mutex),
        Depends =>
          (Sock  => (Sock, How),
           Error => (Sock, How),
           null  => Net_Mutex),
        Pre => 
          Sock /= null and then
          Sock.S_remoteIpAddr.length > 0,
        Post =>
          Sock /= null and then
          (if Error = NO_ERROR then
             Sock.all = Sock.all'Old);

   procedure Socket_Close
      (Sock : in out Socket)
      with
        Global  => (Input => Net_Mutex),
        Depends => (Sock => Sock, null => Net_Mutex),
        Pre     => Sock /= null,
        Post    => Sock /= null and then 
                   Sock.S_Type = SOCKET_TYPE_UNUSED'Enum_Rep;

   procedure Socket_Set_Tx_Buffer_Size
      (Sock : in out Socket;
       Size :        Buffer_Size)
      with
        Depends => (Sock => (Size, Sock)),
        Pre     => Sock /= null and then
                   Sock.S_Type = Socket_Type'Enum_Rep (SOCKET_TYPE_STREAM) and then
                   Sock.S_remoteIpAddr.length = 0 and then
                   Size > 1 and then
                   Size < 22_880, -- TCP_MAX_TX_BUFFER_SIZE
       Post =>
         Sock.all = Sock.all'Old'Update 
               (txBufferSize => unsigned_long (Size));

   procedure Socket_Set_Rx_Buffer_Size
      (Sock : in out Socket;
       Size :        Buffer_Size)
      with
        Depends => (Sock => (Size, Sock)),
        Pre => 
          Sock /= null and then
          Sock.S_Type = Socket_Type'Enum_Rep (SOCKET_TYPE_STREAM) and then
          Sock.S_remoteIpAddr.length = 0 and then
          Size > 1 and then
          Size < 22_880,
        Post =>
          Sock.all =
          Sock.all'Old'Update (rxBufferSize => unsigned_long (Size));

   procedure Socket_Bind
      (Sock          : in out Socket;
       Local_Ip_Addr :        IpAddr;
       Local_Port    :        Port)
      with
       Depends => (Sock => (Sock, Local_Ip_Addr, Local_Port)),
       Pre => 
         Sock /= null and then
         Sock.S_remoteIpAddr.length = 0 and then
         Sock.S_localIpAddr.length = 0 and then
         (Sock.S_Type = SOCKET_TYPE_STREAM'Enum_Rep or else
          Sock.S_Type = SOCKET_TYPE_DGRAM'Enum_Rep),
       Post => 
         Sock /= null and then
         Sock.all = Sock.all'Old'Update
           (S_localIpAddr => Local_Ip_Addr, S_Local_Port => Local_Port);

   procedure Socket_Listen
      (Sock    : in out Socket;
       Backlog :        Natural;
       Error   :    out Error_T)
      with
        Global => Net_Mutex,
        Depends =>
          (Sock  =>+ Backlog,
           Error =>  (Sock, Backlog),
           null =>Net_Mutex),
        Pre => 
          Sock /= null and then
          Sock.S_Type = SOCKET_TYPE_STREAM'Enum_Rep and then
          Sock.S_localIpAddr.length > 0 and then
          Sock.S_remoteIpAddr.length = 0,
        Post => 
          Sock /= null and then Sock.all = Sock.all'Old;

   procedure Socket_Accept
      (Sock           : in out Socket;
       Client_Ip_Addr :    out IpAddr;
       Client_Port    :    out Port;
       Client_Socket  :    out Socket)
      with
        Depends => 
          (Sock           => Sock,
           Client_Ip_Addr => Sock,
           Client_Port    => Sock,
           Client_Socket  => Sock),
       Pre => Sock /= null and then
              Sock.S_Type = SOCKET_TYPE_STREAM'Enum_Rep and then
              Sock.S_localIpAddr.length > 0 and then
              Sock.S_remoteIpAddr.length = 0,
       Post => Sock.all = Sock.all'Old and then
               Client_Ip_Addr.length > 0 and then
               Client_Port > 0 and then
               Client_Socket /= null and then
               Client_Socket.S_Type = Sock.S_Type and then
               Client_Socket.S_Protocol = Sock.S_Protocol and then
               Client_Socket.S_Local_Port = Sock.S_Local_Port and then
               Client_Socket.S_localIpAddr = Sock.S_localIpAddr and then
               Client_Socket.S_remoteIpAddr = Client_Ip_Addr and then
               Client_Socket.S_Remote_Port = Client_Port;

end Socket_Interface;
