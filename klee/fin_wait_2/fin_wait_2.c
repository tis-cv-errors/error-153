#include "core/socket.h"
#include "klee/klee.h"
#include "core/tcp_misc.h"
#include <assert.h>
#include <stdlib.h>
#include "model.h"
#include "core/tcp_timer.h"

void tcpStateFinWait2(Socket *socket, TcpHeader *segment,
                      const NetBuffer *buffer, size_t offset, size_t length)
{
    //Debug message
    // TRACE_DEBUG("TCP FSM: FIN-WAIT-2 state\r\n");

    //First check sequence number
    if (tcpCheckSequenceNumber(socket, segment, length))
        return;

    //Check the RST bit
    if (segment->flags & TCP_FLAG_RST)
    {
        //Switch to the CLOSED state
        tcpChangeState(socket, TCP_STATE_CLOSED);
        //Return immediately
        return;
    }

    //Check the SYN bit
    if (tcpCheckSyn(socket, segment, length))
        return;
    //Check the ACK field
    if (tcpCheckAck(socket, segment, length))
        return;
    //Process the segment text
    if (length > 0)
        tcpProcessSegmentData(socket, segment, buffer, offset, length);

    //Check the FIN bit
    if (segment->flags & TCP_FLAG_FIN)
    {
        //The FIN can only be acknowledged if all the segment data
        //has been successfully transferred to the receive buffer
        if (socket->rcvNxt == (segment->seqNum + length))
        {
            //Advance RCV.NXT over the FIN
            socket->rcvNxt++;
            //Send an acknowledgment for the FIN
            tcpSendSegment(socket, TCP_FLAG_ACK, socket->sndNxt, socket->rcvNxt, 0, FALSE);

            //Release previously allocated resources
            tcpDeleteControlBlock(socket);
            //Start the 2MSL timer
            tcpTimerStart(&socket->timeWaitTimer, TCP_2MSL_TIMER);
            //Switch to the TIME_WAIT state
            tcpChangeState(socket, TCP_STATE_TIME_WAIT);
        }
    }
}

int main()
{
    // Initialisation
    socketInit();

    Socket *socket;
    TcpHeader *segment;
    size_t length, offset;
    uint32_t ackNum, seqNum;
    uint8_t flags, dataOffset;
    uint16_t checksum;
    struct socketModel *sModel;
    NetBuffer *buffer;

    segment = malloc(sizeof(TcpHeader));

    // creation of a TCP socket
    socket = socketOpen(SOCKET_TYPE_STREAM, SOCKET_IP_PROTO_TCP);

    // TODO: See if it is the correct way to process.
    // Maybe open the connection by following the real call of the function
    // is a better way to do.
    tcpChangeState(socket, TCP_STATE_FIN_WAIT_2);

    klee_make_symbolic(&ackNum, sizeof(ackNum), "ackNum");
    klee_make_symbolic(&seqNum, sizeof(seqNum), "seqNum");
    klee_make_symbolic(&flags, sizeof(flags), "flags");
    klee_assume(flags >= 0 && flags <= 31);
    klee_make_symbolic(&checksum, sizeof(checksum), "checksum");
    klee_make_symbolic(&dataOffset, sizeof(dataOffset), "dataOffset");
    klee_assume(0 <= dataOffset && dataOffset <= 15);

    segment->srcPort = 80;
    segment->destPort = socket->localPort;
    segment->seqNum = seqNum;
    segment->ackNum = ackNum;
    segment->reserved1 = 0;
    segment->dataOffset = dataOffset;
    segment->flags = flags;
    segment->reserved2 = 0;
    segment->window = 26883; // Voir ce que c'est exactement
    segment->checksum = checksum;
    segment->urgentPointer = 0;

    // We can assume that length, offset and buffer are null
    // TODO: See after to model a not empty buffer
    length = 0;
    offset = 0;
    buffer = NULL;
    //klee_make_symbolic(&length, sizeof(length), "length");

    // We make a hard copy of the struct to check if the fields have
    // changed after the call to the function
    sModel = toSockModel(socket);

    klee_assert(socket->state == TCP_STATE_FIN_WAIT_2);

    tcpStateFinWait2(socket, segment, buffer, offset, length);

    klee_assert(equalSocketModel(socket, sModel) &&
                (socket->state == TCP_STATE_FIN_WAIT_2 ||
                 socket->state == TCP_STATE_TIME_WAIT ||
                 (socket->state == TCP_STATE_CLOSED &&
                  socket->resetFlag)));
}
