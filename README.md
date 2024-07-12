Environdent Order Tracking
--------------------------

### Overview

This project automates the process of tracking Environdent orders. It consists of a Node.js server, a Puppeteer script for automation, and a Google Apps Script for email processing.

### Table of Contents

-   [Installation](#installation)
-   [Configuration](#configuration)
-   [Usage](#usage)
-   [File Structure](#file-structure)
-   [Google Apps Script](#google-apps-script)
-   [Contributing](#contributing)
-   [License](#license)

### Installation

1.  Clone the repository:

    `git clone https://github.com/hu-friedy/Environdent-Order-Tracking.git
    cd Environdent-Order-Tracking`

2.  Install dependencies:

    `npm install`

3.  Set up environment variables: Create a `.env` file in the root directory and add the following:

    ```bash
    PORT=3000
    NODE_ENV=production
    AUTH_TOKEN=your_auth_token_here
    ```

### Configuration

-   Ensure you have a valid Google Sheet with the necessary structure and an appropriate Gmail label set up for processing.
-   Update the Google Apps Script with your specific Google Sheet ID and Gmail label names.
-   Deploy the Node.js server on an EC2 instance or any suitable server environment.

### Usage

1.  **Run the Server:**

    ```bash
    node server.js
    ```

    Or use PM2 for continuous operation:

    ```bash
    pm2 start server.js
    ```

3.  **Run the Puppeteer Script Manually:**

    ```bash
    node upload-script.js
    ```

### File Structure

```
Environdent-Order-Tracking/
├── .env
├── .gitignore
├── README.md
├── appscript/
│   └── Code.gs
├── package.json
├── server.js
├── upload-script.js
├── uploads/
├── screenshots/
└── logs/
    ├── combined.log
    └── error.log
```

-   `server.js`: The main server file.
-   `upload-script.js`: The Puppeteer script for automation.
-   `appscript/Code.gs`: The Google Apps Script code.
-   `uploads/`: Directory for uploaded files.
-   `screenshots/`: Directory for screenshots.
-   `logs/`: Directory for log files.

### Google Apps Script

The Google Apps Script code is located in the `appscript/Code.gs` file. It checks for new emails, processes HTML attachments, updates a Google Sheet, and sends the updated sheet to the EC2 instance.

### Additional Information for Server Configuration

Instance summary for i-021096a854790abf3 (Environdent Order Tracking Automation):

-   **Instance ID:** i-021096a854790abf3
-   **Public IPv4 address:** 3.94.190.212
-   **Private IPv4 addresses:** 172.31.19.195
-   **Instance state:** Running
-   **Public IPv4 DNS:** ec2-3-94-190-212.compute-1.amazonaws.com
-   **Hostname type:** IP name: ip-172-31-19-195.ec2.internal
-   **Private IP DNS name (IPv4 only):** ip-172-31-19-195.ec2.internal
-   **Instance type:** t2.micro
-   **VPC ID:** vpc-6b712013
-   **Subnet ID:** subnet-814100ca
-   **IMDSv2:** Required
-   **Instance ARN:** arn:aws:ec2:us-east-1:178045829714/i-021096a854790abf3

This instance is under the hufriedydigital AWS account.

### Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

### Issues and Feature Requests

If you encounter any issues or have ideas for new features, please open an issue on the GitHub repository.
