from hysds.es_util import get_grq_es

grq_es = get_grq_es()

print("Deleting data indices from", grq_es.es_url)
_data_indices = ['grq_v2.0_l2_hls_l30', 'grq_v2.0_l2_hls_s30', 'grq_1_opera_state_config', 'grq_v1.1.5_triaged_job',
        'grq_v0.1_l3_dswx_hls','grq_v1.0_l3_dswx_hls', 'grq_1_l2_hls_s30-state-config', 'grq_1_l2_hls_l30-state-config',
        'grq_v0.0_l2_rtc_s1', 'grq_v0.0_l2_cslc_s1']

for i in _data_indices:
    print("Deleting index", i)
    print(grq_es.es.indices.delete(index=i, ignore=[404]))

