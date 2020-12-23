// Copyright (c) Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

#pragma once

#include <memory>
#include <mutex>
#include <string>

#include <azure/core/http/http.hpp>

namespace Azure { namespace Storage {

  namespace Sas {
    struct AccountSasBuilder;
    struct BlobSasBuilder;
    struct ShareSasBuilder;
    struct DataLakeSasBuilder;
  } // namespace Sas

  namespace Details {
    class SharedKeyPolicy;
  }

  /**
   * @brief A StorageSharedKeyCredential is a credential backed by a storage account's name and
   * one of its access keys.
   */
  class StorageSharedKeyCredential {
  public:
    /**
     * @brief Initializes a new instance of the StorageSharedKeyCredential.
     *
     * @param accountName Name of the storage account.
     * @param accountKey Access key of the storage
     * account.
     */
    explicit StorageSharedKeyCredential(std::string accountName, std::string accountKey)
        : AccountName(std::move(accountName)), m_accountKey(std::move(accountKey))
    {
    }

    /**
     * @brief Update the storage account's access key. This intended to be used when you've
     * regenerated your storage account's access keys and want to update long lived clients.
     *
     * @param accountKey A storage account access key.
     */
    void Update(std::string accountKey)
    {
      std::lock_guard<std::mutex> guard(m_mutex);
      m_accountKey = std::move(accountKey);
    }

    /**
     * @brief Gets the name of the Storage Account.
     */
    const std::string AccountName;

  private:
    friend class Details::SharedKeyPolicy;
    friend struct Sas::BlobSasBuilder;
    friend struct Sas::ShareSasBuilder;
    friend struct Sas::DataLakeSasBuilder;
    friend struct Sas::AccountSasBuilder;
    std::string GetAccountKey() const
    {
      std::lock_guard<std::mutex> guard(m_mutex);
      return m_accountKey;
    }

    mutable std::mutex m_mutex;
    std::string m_accountKey;
  };

  namespace Details {

    struct ConnectionStringParts
    {
      Azure::Core::Http::Url BlobServiceUrl;
      Azure::Core::Http::Url FileServiceUrl;
      Azure::Core::Http::Url QueueServiceUrl;
      Azure::Core::Http::Url DataLakeServiceUrl;
      std::shared_ptr<StorageSharedKeyCredential> KeyCredential;
    };

    ConnectionStringParts ParseConnectionString(const std::string& connectionString);

  } // namespace Details

}} // namespace Azure::Storage
