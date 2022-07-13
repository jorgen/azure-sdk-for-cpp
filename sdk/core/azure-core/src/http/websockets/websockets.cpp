// Copyright (c) Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

#include "azure/core/http/websockets/websockets.hpp"
#include "azure/core/context.hpp"
#include "websocketsimpl.hpp"

namespace Azure { namespace Core { namespace Http { namespace WebSockets {
  WebSocket::WebSocket(Azure::Core::Url const& remoteUrl, WebSocketOptions const& options)
      : m_socketImplementation(
          std::make_unique<_detail::WebSocketImplementation>(remoteUrl, options))

  {
  }
  WebSocket::~WebSocket() {}

  void WebSocket::Open(Azure::Core::Context const& context)
  {
    m_socketImplementation->Open(context);
  }
  void WebSocket::Close(Azure::Core::Context const& context)
  {
    m_socketImplementation->Close(context);
  }
  void WebSocket::Close(
      uint16_t closeStatus,
      std::string const& closeReason,
      Azure::Core::Context const& context)
  {
    m_socketImplementation->Close(closeStatus, closeReason, context);
  }

  void WebSocket::SendFrame(
      std::string const& textFrame,
      bool isFinalFrame,
      Azure::Core::Context const& context)
  {
    m_socketImplementation->SendFrame(textFrame, isFinalFrame, context);
  }

  void WebSocket::SendFrame(
      std::vector<uint8_t> const& binaryFrame,
      bool isFinalFrame,
      Azure::Core::Context const& context)
  {
    m_socketImplementation->SendFrame(binaryFrame, isFinalFrame, context);
  }

  std::shared_ptr<WebSocketFrame> WebSocket::ReceiveFrame(Azure::Core::Context const& context)
  {
    return m_socketImplementation->ReceiveFrame(context);
  }

  void WebSocket::SendPing(
      std::vector<uint8_t> const& pingData,
      Azure::Core::Context const& context)
  {
    m_socketImplementation->SendPing(pingData, context);
  }

  void WebSocket::AddHeader(std::string const& headerName, std::string const& headerValue)
  {
    m_socketImplementation->AddHeader(headerName, headerValue);
  }
  std::string const& WebSocket::GetChosenProtocol() const
  {
    return m_socketImplementation->GetChosenProtocol();
  }

  bool WebSocket::IsOpen() { return m_socketImplementation->IsOpen(); }

  std::shared_ptr<WebSocketTextFrame> WebSocketFrame::AsTextFrame()
  {
    if (FrameType != WebSocketFrameType::TextFrameReceived)
    {
      throw std::logic_error("Cannot cast to TextFrameReceived.");
    }
    return static_cast<WebSocketTextFrame*>(this)->shared_from_this();
  }

  std::shared_ptr<WebSocketBinaryFrame> WebSocketFrame::AsBinaryFrame()
  {
    if (FrameType != WebSocketFrameType::BinaryFrameReceived)
    {
      throw std::logic_error("Cannot cast to BinaryFrameReceived.");
    }
    return static_cast<WebSocketBinaryFrame*>(this)->shared_from_this();
  }

  std::shared_ptr<WebSocketPeerCloseFrame> WebSocketFrame::AsPeerCloseFrame()
  {
    if (FrameType != WebSocketFrameType::PeerClosedReceived)
    {
      throw std::logic_error("Cannot cast to PeerClose.");
    }
    return static_cast<WebSocketPeerCloseFrame*>(this)->shared_from_this();
  }
  std::shared_ptr<WebSocketPongFrame> WebSocketFrame::AsPongFrame()
  {
    if (FrameType != WebSocketFrameType::PongReceived)
    {
      throw std::logic_error("Cannot cast to PongReceived.");
    }
    return static_cast<WebSocketPongFrame*>(this)->shared_from_this();
  }

}}}} // namespace Azure::Core::Http::WebSockets
