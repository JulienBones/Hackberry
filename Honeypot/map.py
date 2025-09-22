# -*- coding: utf-8 -*-
###### ADAPTEZ LES CHEMINS !!
#### Dépendence : python3-geoip2 python3-plotly python3-pandas python3-folium
import geoip2.database
import folium
from folium.plugins import HeatMap
import ipaddress
import plotly.express as px
import pandas as pd

# Chemin vers ta base GeoLite2 City
geoip_db_path = '/home/joe/honeypot/map/GeoLite2-City.mmdb'

# Lecture des données depuis ip.txt avec gestion des espaces
ips_data = []
with open('/home/joe/honeypot/ip.txt', 'r') as f:
    for line in f:
        parts = [p for p in line.strip().split(' ') if p]
        if len(parts) == 2:
            count_str, ip_str = parts
            try:
                count = int(count_str)
                ip = ip_str
                print(f"Parsed count: {count}, ip: {ip}")
                ips_data.append((count, ip))
            except Exception as e:
                print(f"Erreur dans la ligne: '{line.strip()}', {e}")
        else:
            print(f"Ligne ignorée (mauvais format): '{line.strip()}'")

def is_public_ip(ip_addr):
    try:
        ip_obj = ipaddress.ip_address(ip_addr)
        return not ip_obj.is_private
    except:
        return False

reader = geoip2.database.Reader(geoip_db_path)

locations = []
for count, ip in ips_data:
    if not is_public_ip(ip):
        print(f"Ignored private IP: {ip}")
        continue
    try:
        response = reader.city(ip)
        lat = response.location.latitude
        lon = response.location.longitude
        country = response.country.name if response.country.name else "Unknown"
        print(f"Géoloc IP: {ip} -> Lat: {lat}, Lon: {lon}, Pays: {country}")
        if lat is not None and lon is not None:
            locations.append((count, ip, lat, lon, country))
    except Exception as e:
        print(f"Erreur géoloc IP {ip}: {e}")

if not locations:
    print("Aucune IP géolocalisée.")
    exit()

# Calcul correct des moyennes en extrayant latitude et longitude
avg_lat = sum(l[2] for l in locations) / len(locations)
avg_lon = sum(l[3] for l in locations) / len(locations)

def get_color(count):
    if count > 1000:
        return 'red'
    elif count > 100:
        return 'orange'
    else:
        return 'green'

# Carte Folium colorée
m = folium.Map(location=[avg_lat, avg_lon], zoom_start=2)
for count, ip, lat, lon, country in locations:
    color = get_color(count)
    folium.CircleMarker(
        location=[lat, lon],
        radius=3 + count ** 0.5,
        color=color,
        fill=True,
        fill_opacity=0.7,
        popup=f"{ip}\nAttaques: {count}\nPays: {country}"
    ).add_to(m)
m.save('/home/joe/honeypot/map/map_honeypot_ips_colored.html')
print("Carte colorée enregistrée sous map_honeypot_ips_colored.html")

# Heatmap Folium
heatmap = folium.Map(location=[avg_lat, avg_lon], zoom_start=2)
heat_data = [[l[2], l[3], l[0]] for l in locations]  # lat, lon, count
HeatMap(heat_data, min_opacity=0.5, radius=15, blur=30).add_to(heatmap)
heatmap.save('/home/joe/honeypot/map/map_honeypot_ips_heatmap.html')
print("Heatmap enregistrée sous map_honeypot_ips_heatmap.html")

# Histogramme Plotly des attaques par pays
df = pd.DataFrame(locations, columns=['count', 'ip', 'lat', 'lon', 'country'])
agg = df.groupby('country')['count'].sum().reset_index()
fig = px.bar(agg, x='country', y='count', title='Nombre total d’attaques par pays')
fig.write_html('/home/joe/honeypot/map/histogramme_attaques_pays.html')
print("Histogramme enregistré sous histogramme_attaques_pays.html")
