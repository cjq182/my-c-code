#include <stdio.h>

int main()
{
	const int amount = 100;
	int price = 0;
	
	printf("请输入金额（元）：");
	scanf("%d", &price);
	int change =amount - price;
	printf("找零%d元。\n", change);
	return 0;
}

