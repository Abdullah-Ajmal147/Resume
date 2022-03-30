from django.shortcuts import render
from .models import data

# Create your views here.
def test(request):
    datas = data.objects.all()
    context ={'data': datas}
    return render(request,'Cv/index.html', context)
