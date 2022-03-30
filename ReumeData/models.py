from django.db import models

# Create your models here.
class data(models.Model):
    name= models.CharField(max_length=50, blank=True)
    about_me=models.CharField(max_length=250, blank= True)
    about_image = models.ImageField(upload_to= 'photos/about', blank=True)
    
    def __str__(self):
        return self.name

    
