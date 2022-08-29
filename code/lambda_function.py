import json
import socket
import os, sys
import logging
import boto3


####### Get values from environment variables  ######

DOMAIN_NAMES=os.environ['DOMAIN_NAMES'].strip().split(',')

WAF_IP_SET_ID=os.environ['WAF_IP_SET_ID'].strip()
WAF_IP_SET_NAME=os.environ['WAF_IP_SET_NAME'].strip()

  # Determine whether to set INFO level for logging
DEFAULT_LOG_LEVEL = logging.ERROR
LOG_LEVEL = os.getenv('LOG_LEVEL',DEFAULT_LOG_LEVEL)
if LOG_LEVEL == ['']: LOG_LEVEL = DEFAULT_LOG_LEVEL

def lambda_handler(event, context):

    # Set up logging. Set the level if the handler is already configured.
    if len(logging.getLogger().handlers) > 0:
        logging.getLogger().setLevel(DEFAULT_LOG_LEVEL)
    else:
        logging.basicConfig(level=DEFAULT_LOG_LEVEL)
    
    # Set the environment variable DEBUG to 'true' if you want verbose debug details in CloudWatch Logs.
    if LOG_LEVEL:
        logging.getLogger().setLevel(LOG_LEVEL)

    domain_names = strip_list(DOMAIN_NAMES)

    #### environment variables validations

    # cancel everything if DOMAIN_NAMES is empty and log a message
    if not domain_names or domain_names == ['']:
        logging.error(f'Environment variable DOMAIN_NAMES is empty: [{DOMAIN_NAMES}], please fill in a list of domains separated by commas to look up IPs')
        sys.exit(0)

    # cancel everything with an error if WAF_IP_SET_ID or WAF_IP_SET_NAME are empty
    if not WAF_IP_SET_NAME or not WAF_IP_SET_ID:
        logging.error(f'Missing WAF_IP_SET_NAME and/or WAF_IP_SET_ID environment variables, current values: [{WAF_IP_SET_NAME}], [{WAF_IP_SET_ID}]')
        sys.exit(0)

    logging.debug(f'Log level is [{LOG_LEVEL}]')
    logging.debug(f'Domains for which a lookup is going to be done: [{" ".join(domain_names)}]')
    logging.debug(f'WAF IP Set name is [{WAF_IP_SET_NAME}]')

    ips = []
    for domain_name in domain_names:
        logging.debug(f'Resolving [{domain_name}]')
        # note that if any of the domains don't exist or is not responding, the lambda function will exit with an exception
        result = socket.gethostbyname_ex(domain_name)
        for ipval in result[2]:
            logging.debug(f'IP address found [{ipval}]')
            ips.append(ipval+'/32')

    update_waf_ipset(WAF_IP_SET_NAME, WAF_IP_SET_ID, ips)

    return {
        'statusCode': 200,
        'body': json.dumps(f'Succeeded updating IP Set [{WAF_IP_SET_NAME}]')
    }

def update_waf_ipset(ipset_name,ipset_id,address_list):
    """Updates the AWS WAF IP set"""
    waf_client = boto3.client('wafv2')

    lock_token = get_ipset_lock_token(waf_client,ipset_name,ipset_id)

    logging.info(f'Got LockToken for AWS WAF IP Set "{ipset_name}": {lock_token}')

    waf_client.update_ip_set(
        Name=ipset_name,
        Scope='REGIONAL',
        Id=ipset_id,
        Addresses=address_list,
        LockToken=lock_token
    )

    logging.info(f'Updated IPSet "{ipset_name}" with {len(address_list)} CIDRs')

def get_ipset_lock_token(client,ipset_name,ipset_id):
    """Returns the AWS WAF IP set lock token"""
    ip_set = client.get_ip_set(
        Name=ipset_name,
        Scope='REGIONAL',
        Id=ipset_id)
    
    return ip_set['LockToken']

def strip_list(list):
    """Strips individual elements of the strings"""
    return [item.strip() for item in list]