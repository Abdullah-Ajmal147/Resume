# Generated by Django 3.2.6 on 2022-03-30 10:25

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('ReumeData', '0002_data_name'),
    ]

    operations = [
        migrations.AddField(
            model_name='data',
            name='about_me',
            field=models.CharField(blank=True, max_length=250),
        ),
    ]
