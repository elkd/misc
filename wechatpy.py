import logging
import hashlib
import xmltodict
import dicttoxml
import time
import requests
import random
import string
from random import Random

from ipware import get_client_ip
from bs4 import BeautifulSoup
from django.core.cache import cache
from config.settings.base import env

from wechatpy.pay.api import WeChatOrder
from wechatpy.pay import WeChatPay
from wechatpy.exceptions import WeChatPayException


APPID = env('WECHAT_APPID')
APP_SECRET = env('WECHAT_APPSECRET')
API_KEY = env('WECHAT_API_KEY')
# On wechat merchant ac, account settings then security API
MCH_ID = env.int('WECHAT_MERCHANT_ID')
MCHID = MCH_ID + 1 - 1
WXORDER_URL = "https://api.mch.weixin.qq.com/pay/unifiedorder"
NOTIFY_URL = "https://obrisk.com/classifieds/wsguatpotlfwccdi/wxjsapipy/inwxpy_results"


def random_str(randomlength=8):
    """
    Generate random string
    :param randomlength: string length
    :return sting:
    """
    str = ''
    chars = 'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz0123456789'
    length = len(chars) - 1
    random = Random()
    for i in range(randomlength):
        str+=chars[random.randint(0, length)]
    return str



def create_out_trade_no():
        """
        创建微信商户订单号
        :return:
        """
        local_time = time.strftime('%Y%m%d%H%M%S', time.localtime(time.time()))
        result = 'wx{}'.format(local_time[2:])
        return result


def get_jsapi_params(request, openid, title, details, total_fee):
    """
    Get the parameters required for WeChat Jsapi payment
    :param openid: 用户的openid
    :return:
    """
    client_ip = cache.get(
            f'user_ipaddr_{openid}'
        )
    if client_ip is None:
        client_ip, _ = get_client_ip(
                request,
                proxy_trusted_ips=['63.0.0.5','63.1']
            )

        cache.set(
                f'user_ipaddr_{openid}',
                client_ip,
                60 * 60 * 2
            )
    params = {
        'appid': APPID,  # APPID
        'body':  '{0}'.format(details), # 商品描述
        'attach': '{0}'.format(title),  # 商品描述
        'mch_id': MCHID,  # 商户号
        'nonce_str': random_str(16),  # 随机字符串
        'notify_url': NOTIFY_URL,  # 微信支付结果回调url
        'openid': openid,
        'out_trade_no': create_out_trade_no(),  # 订单号
        'spbill_create_ip': client_ip,  # 发送请求服务器的IP地址
        'total_fee': int(round(float(total_fee), 2) * 100),  # 订单总金额,1代表1分钱
        'trade_type': 'JSAPI'
    }
    # 调用微信统一下单支付接口url

    #params['sign'] = get_sign(params, API_KEY)
    #notify_result = wx_pay_unifiedorder(params)
    #notify_result = xmltodict.parse(notify_result)['xml']
    client = WeChatPay(APPID, API_KEY, MCHID)
   
    try:
        notify_result = client.order.create(
                params['trade_type'], 
                params['body'], 
                params['total_fee'], 
                params['notify_url'], 
                user_id = params['openid'], 
                client_ip = params['spbill_create_ip']
            )
    except WeChatPayException as e:
        return {'error': e}
    except Exception as e:
        logging.error('Wechat py Exception', exc_info=e)
        return {'error': f'Wechat pay failed {e}'}

    else:
        if 'return_code' in notify_result and notify_result['return_code'] == 'FAIL':
            return {'error': notify_result['return_msg']}
        if 'prepay_id' not in notify_result:
            params['prepay_id'] = notify_result['prepay_id']
            params['timeStamp'] = int(time.time())
            params['nonceStr'] = random_str(16)
            params['sign'] = get_sign({'appId': APPID,
                               "timeStamp": params['timeStamp'],
                               'nonceStr': params['nonceStr'],
                               'package': 'prepay_id=' + params['prepay_id'],
                               'signType': 'MD5',
                           },
                           API_KEY
                       )
            ret_params = {
                'package': "prepay_id=" + params['prepay_id'],
                'appid': APPID,
                'timeStamp': str(params['timeStamp']),
                'nonceStr': params['nonceStr'],
                'sign': params['sign'],

            }
            return ret_params
